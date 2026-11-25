package main

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"os"
	"os/signal"
	"runtime"
	"slices"
	"strings"
	"syscall"
	"time"

	"github.com/jezek/xgb"
)

const version = "0.1.0"

const usage = `offhand-linux-probe inspect
offhand-linux-probe plan [OUTPUT1 OUTPUT2]
offhand-linux-probe trial [OUTPUT1 OUTPUT2]

inspect and plan are read-only. trial asks before a 15-second windowed span.
For more than two monitors, supply two names exactly as printed by inspect.`

func plan(monitors []monitor, names []string) (rect, error) {
	pair := monitors
	if len(names) != 0 {
		if len(names) != 2 || names[0] == names[1] {
			return rect{}, errors.New("choose two different output names")
		}
		pair = nil
		for _, m := range monitors {
			if slices.Contains(names, m.name) {
				pair = append(pair, m)
			}
		}
	}
	if len(pair) != 2 {
		return rect{}, errors.New("choose two active outputs from inspect")
	}
	a, b := pair[0].box, pair[1].box
	if a.X > b.X {
		a, b = b, a
	}
	top, bottom := max(a.Y, b.Y), min(a.Y+a.H, b.Y+b.H)
	if a.X+a.W != b.X || bottom-top < 480 || min(a.W, b.W) < 320 {
		return rect{}, errors.New("this trial needs adjacent side-by-side outputs with at least 480 pixels of common height")
	}
	// Leave room for existing decorations and desktop panels. The probe
	// exercises placement without altering fullscreen, border or tiling hints.
	const margin = 64
	return rect{a.X + margin, top + margin, a.W + b.W - 2*margin, bottom - top - 2*margin}, nil
}

type windowControl interface {
	ordinary(target) error
	boundsFor(target) (rect, error)
	move(target, rect) error
	monitors() ([]monitor, error)
}

func (d *desktop) boundsFor(t target) (rect, error) { return d.bounds(t.id) }

func sameDesk(d windowControl, before []monitor) bool {
	now, err := d.monitors()
	if err != nil || len(now) != len(before) {
		return false
	}
	for _, m := range before {
		if !slices.Contains(now, m) {
			return false
		}
	}
	return true
}

// Allow asynchronous WM/configure events, including a late size clamp.
func settled(d windowControl, t target, delay time.Duration) (rect, error) {
	time.Sleep(delay)
	first, err := d.boundsFor(t)
	if err != nil {
		return rect{}, err
	}
	for range 6 {
		time.Sleep(delay / 4)
		next, err := d.boundsFor(t)
		if err != nil {
			return rect{}, err
		}
		if next == first {
			return next, nil
		}
		first = next
	}
	return rect{}, errors.New("window did not settle")
}

func trial(ctx context.Context, d windowControl, t target, monitors []monitor, original, wanted rect, delay, hold time.Duration) error {
	start, err := d.boundsFor(t)
	if err != nil || start != original || !sameDesk(d, monitors) {
		return errors.New("window or displays changed after preview; run plan again")
	}
	if ctx.Err() != nil {
		return ctx.Err()
	}
	if err := d.move(t, wanted); err != nil {
		return err
	}
	observed, err := settled(d, t, delay)
	if err != nil {
		return fmt.Errorf("trial readback unavailable; review the original bounds printed above: %w", err)
	}
	fmt.Printf("Trial readback: %s\n", observed)
	matched := observed == wanted
	if matched {
		fmt.Println("Requested bounds observed. Check both displays and click each side now.")
		timer := time.NewTimer(hold)
		select {
		case <-ctx.Done():
		case <-timer.C:
		}
		timer.Stop()
	}
	if err := d.ordinary(t); err != nil {
		return fmt.Errorf("restore needs review; window identity or state changed: %w", err)
	}
	current, err := d.boundsFor(t)
	if err != nil || !sameDesk(d, monitors) {
		return errors.New("restore needs review; window unavailable or monitor arrangement changed")
	}
	if current != original {
		if current != observed {
			return errors.New("window moved again during the trial; leaving the newer placement for manual review")
		}
		if err := d.move(t, original); err != nil {
			return fmt.Errorf("restore request failed: %w", err)
		}
		back, err := settled(d, t, delay)
		if err != nil {
			return fmt.Errorf("restore readback unavailable: %w", err)
		}
		fmt.Printf("Restore readback: %s\n", back)
		if back != original {
			return errors.New("restore differed from original; restore manually using the printed bounds")
		}
	}
	fmt.Println("Original client bounds verified.")
	if !matched {
		return errors.New("requested span was refused or adjusted")
	}
	return nil
}

func distro() string {
	f, err := os.Open("/etc/os-release")
	if err == nil {
		defer f.Close()
		scanner := bufio.NewScanner(f)
		for scanner.Scan() {
			if v, ok := strings.CutPrefix(scanner.Text(), "PRETTY_NAME="); ok {
				return strings.Trim(v, "\"'")
			}
		}
	}
	return "unknown"
}

func run(args []string) error {
	if len(args) == 1 && (args[0] == "--help" || args[0] == "help") {
		fmt.Println(usage)
		return nil
	}
	if len(args) == 0 {
		args = []string{"inspect"}
	}
	command := args[0]
	if !slices.Contains([]string{"inspect", "plan", "trial"}, command) ||
		(len(args) != 1 && (len(args) != 3 || command == "inspect")) {
		return errors.New(usage)
	}
	fmt.Printf("Offhand Linux probe %s | %s/%s | distro %q | desktop %q | session %q\n",
		version, runtime.GOOS, runtime.GOARCH, distro(), os.Getenv("XDG_CURRENT_DESKTOP"), os.Getenv("XDG_SESSION_TYPE"))
	d, err := connect(os.Getenv("DISPLAY"))
	if err != nil {
		return err
	}
	defer d.c.Close()
	monitors, displayErr := d.monitors()
	for _, m := range monitors {
		fmt.Printf("Output %q: %s (X coordinates)\n", m.name, m.box)
	}
	games, err := d.games()
	if err != nil {
		return fmt.Errorf("client discovery: %w", err)
	}
	canMove := d.supported()
	fmt.Printf("WoW X11 windows: %d | manager advertises move/resize: %t\n", len(games), canMove)
	for _, t := range games {
		r, err := d.boundsFor(t)
		if err == nil {
			fmt.Printf("Game class %q: %s\n", t.class, r)
		}
	}
	if len(games) == 0 {
		fmt.Println("No recognized WoW X11 window. Native Wayland, an unrecognized Wine class or a different display are possible.")
	}
	if displayErr != nil {
		return displayErr
	}
	if command == "inspect" {
		return nil
	}
	wanted, err := plan(monitors, args[1:])
	if err != nil {
		return err
	}
	fmt.Printf("Requested trial client bounds: %s\n", wanted)
	if len(games) != 1 || !canMove {
		return errors.New("trial needs one recognized WoW window and advertised EWMH move/resize support")
	}
	t := games[0]
	if err := d.ordinary(t); err != nil {
		return err
	}
	original, err := d.boundsFor(t)
	if err != nil {
		return err
	}
	if !slices.ContainsFunc(monitors, func(m monitor) bool { return m.box.contains(original) }) {
		return errors.New("start with WoW entirely on one screen for a repeatable restore")
	}
	fmt.Printf("Original client bounds: %s\n", original)
	if command == "plan" {
		fmt.Println("Plan ready.")
		return nil
	}
	// Linux abstract sockets release automatically on process exit.
	lock, err := net.Listen("unix", fmt.Sprintf("@offhand-linux-probe-trial-%d", os.Getuid()))
	if err != nil {
		return errors.New("cannot start an exclusive trial; close any other trial and retry")
	}
	defer lock.Close()
	fmt.Println("Keep WoW windowed and floating. Type SPAN and press Enter to start the 15-second trial:")
	line, err := bufio.NewReader(os.Stdin).ReadString('\n')
	if err != nil || strings.TrimSpace(line) != "SPAN" {
		return errors.New("trial cancelled before placement")
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM, syscall.SIGHUP)
	defer stop()
	return trial(ctx, d, t, monitors, original, wanted, 750*time.Millisecond, 15*time.Second)
}

func main() {
	// A terminal or tee may close while a trial is active. A failed status
	// write must still allow the outstanding window restore to finish.
	signal.Ignore(syscall.SIGPIPE)
	// The X library can otherwise log local authority-file paths.
	xgb.Logger = log.New(io.Discard, "", 0)
	if err := run(os.Args[1:]); err != nil {
		fmt.Println("Result:", err)
		os.Exit(1)
	}
}
