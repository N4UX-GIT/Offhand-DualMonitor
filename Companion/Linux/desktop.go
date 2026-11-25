package main

import (
	"errors"
	"fmt"
	"regexp"
	"slices"
	"strings"

	"github.com/jezek/xgb"
	"github.com/jezek/xgb/randr"
	"github.com/jezek/xgb/xproto"
)

type rect struct{ X, Y, W, H int }

func (r rect) String() string {
	return fmt.Sprintf("%dx%d%+d%+d", r.W, r.H, r.X, r.Y)
}

func (r rect) contains(s rect) bool {
	return s.W > 0 && s.H > 0 && s.X >= r.X && s.Y >= r.Y && s.X+s.W <= r.X+r.W && s.Y+s.H <= r.Y+r.H
}

type monitor struct {
	name string
	box  rect
}

type target struct {
	id    xproto.Window
	pid   uint32
	class string
}

// Match a complete Wine WM_CLASS component. Battle.net and incidental WoW
// words in other applications' window titles must never become trial targets.
var gameClass = regexp.MustCompile(`(?i)^wow(?:classic(?:era|t|b)?|forever|t|b)?\.exe$`)

func wowClass(raw []byte) string {
	for _, part := range strings.Split(string(raw), "\x00") {
		if gameClass.MatchString(part) {
			return strings.ToLower(part)
		}
	}
	return ""
}

type desktop struct {
	c     *xgb.Conn
	root  xproto.Window
	atoms map[string]xproto.Atom
}

func connect(display string) (*desktop, error) {
	if !regexp.MustCompile(`^:[0-9]+(?:\.[0-9]+)?$`).MatchString(display) {
		return nil, errors.New("local X11 display unavailable; record your session and runner (native Wayland windows need a separate adapter)")
	}
	c, err := xgb.NewConnDisplay(display)
	if err != nil {
		return nil, errors.New("cannot open the local X display; run in a terminal on the same desktop as WoW")
	}
	setup := xproto.Setup(c)
	if c.DefaultScreen >= len(setup.Roots) {
		c.Close()
		return nil, errors.New("X screen unavailable")
	}
	return &desktop{c, setup.DefaultScreen(c).Root, make(map[string]xproto.Atom)}, nil
}

func (d *desktop) atom(name string) (xproto.Atom, error) {
	if a, ok := d.atoms[name]; ok {
		return a, nil
	}
	reply, err := xproto.InternAtom(d.c, true, uint16(len(name)), name).Reply()
	if err != nil {
		return 0, err
	}
	// A later client can introduce an atom during the trial.
	if reply.Atom != 0 {
		d.atoms[name] = reply.Atom
	}
	return reply.Atom, nil
}

func (d *desktop) property(w xproto.Window, name string, kind xproto.Atom, format byte) ([]byte, error) {
	a, err := d.atom(name)
	if err != nil || a == 0 {
		return nil, err
	}
	p, err := xproto.GetProperty(d.c, false, w, a, kind, 0, 65536).Reply()
	if err != nil || p.Type == 0 {
		return nil, err
	}
	if p.Type != kind || p.Format != format || p.BytesAfter != 0 {
		return nil, fmt.Errorf("unexpected %s property", name)
	}
	return p.Value, nil
}

func (d *desktop) words(w xproto.Window, name string, kind xproto.Atom) ([]uint32, error) {
	raw, err := d.property(w, name, kind, 32)
	if err != nil {
		return nil, err
	}
	var words []uint32
	for len(raw) >= 4 {
		words = append(words, xgb.Get32(raw))
		raw = raw[4:]
	}
	return words, nil
}

func (d *desktop) monitors() ([]monitor, error) {
	if err := randr.Init(d.c); err != nil {
		return nil, errors.New("RandR unavailable")
	}
	v, err := randr.QueryVersion(d.c, 1, 5).Reply()
	if err != nil || (v.MajorVersion == 1 && v.MinorVersion < 5) || v.MajorVersion < 1 {
		return nil, errors.New("RandR 1.5 monitor discovery unavailable")
	}
	reply, err := randr.GetMonitors(d.c, d.root, true).Reply()
	if err != nil {
		return nil, err
	}
	var result []monitor
	for _, m := range reply.Monitors {
		n, err := xproto.GetAtomName(d.c, m.Name).Reply()
		if err != nil {
			return nil, err
		}
		result = append(result, monitor{n.Name, rect{int(m.X), int(m.Y), int(m.Width), int(m.Height)}})
	}
	return result, nil
}

func (d *desktop) identity(w xproto.Window) (target, error) {
	raw, err := d.property(w, "WM_CLASS", xproto.AtomString, 8)
	if err != nil {
		return target{}, err
	}
	t := target{id: w, class: wowClass(raw)}
	if t.class != "" {
		p, err := d.words(w, "_NET_WM_PID", xproto.AtomCardinal)
		if err != nil {
			return target{}, err
		}
		if len(p) == 1 {
			t.pid = p[0]
		}
	}
	return t, nil
}

func (d *desktop) games() ([]target, error) {
	ids, err := d.words(d.root, "_NET_CLIENT_LIST", xproto.AtomWindow)
	if err != nil {
		return nil, err
	}
	var found []target
	for _, id := range ids {
		t, err := d.identity(xproto.Window(id))
		if err != nil {
			// A short-lived client may have disappeared since enumeration.
			if _, gone := err.(xproto.WindowError); gone {
				continue
			}
			return nil, err
		}
		if t.class != "" {
			found = append(found, t)
		}
	}
	return found, nil
}

func (d *desktop) supported() bool {
	a, err := d.atom("_NET_MOVERESIZE_WINDOW")
	if err != nil || a == 0 {
		return false
	}
	list, err := d.words(d.root, "_NET_SUPPORTED", xproto.AtomAtom)
	return err == nil && slices.Contains(list, uint32(a))
}

func (d *desktop) bounds(w xproto.Window) (rect, error) {
	g, err := xproto.GetGeometry(d.c, xproto.Drawable(w)).Reply()
	if err != nil {
		return rect{}, err
	}
	p, err := xproto.TranslateCoordinates(d.c, w, d.root, 0, 0).Reply()
	if err != nil || !p.SameScreen {
		return rect{}, errors.New("client position unavailable")
	}
	return rect{int(p.DstX), int(p.DstY), int(g.Width), int(g.Height)}, nil
}

func (d *desktop) ordinary(t target) error {
	got, err := d.identity(t.id)
	if err != nil || got != t || t.pid == 0 {
		return errors.New("WoW window identity is missing or changed")
	}
	attrs, err := xproto.GetWindowAttributes(d.c, t.id).Reply()
	if err != nil || attrs.MapState != xproto.MapStateViewable || attrs.OverrideRedirect {
		return errors.New("WoW must be a visible, managed window")
	}
	types, err := d.words(t.id, "_NET_WM_WINDOW_TYPE", xproto.AtomAtom)
	if err != nil {
		return err
	}
	normal, err := d.atom("_NET_WM_WINDOW_TYPE_NORMAL")
	if err != nil || (len(types) > 0 && types[0] != uint32(normal)) {
		return errors.New("WoW must be an ordinary application window")
	}
	states, err := d.words(t.id, "_NET_WM_STATE", xproto.AtomAtom)
	if err != nil {
		return err
	}
	for _, name := range []string{"FULLSCREEN", "MAXIMIZED_VERT", "MAXIMIZED_HORZ", "HIDDEN", "SHADED"} {
		a, err := d.atom("_NET_WM_STATE_" + name)
		if err != nil {
			return err
		}
		if a != 0 && slices.Contains(states, uint32(a)) {
			return fmt.Errorf("WoW state %s; use a smaller, visible Windowed window", name)
		}
	}
	return nil
}

func (d *desktop) move(t target, r rect) error {
	if err := d.ordinary(t); err != nil {
		return err
	}
	a, err := d.atom("_NET_MOVERESIZE_WINDOW")
	if err != nil || a == 0 {
		return errors.New("window manager lacks move/resize")
	}
	// EWMH StaticGravity addresses the client origin. Set x/y/w/h flags
	// and source 2 (external window-management utility).
	data := []uint32{10 | 0xf00 | 0x2000, uint32(r.X), uint32(r.Y), uint32(r.W), uint32(r.H)}
	event := xproto.ClientMessageEvent{Format: 32, Window: t.id, Type: a, Data: xproto.ClientMessageDataUnionData32New(data)}
	return xproto.SendEventChecked(d.c, false, d.root,
		xproto.EventMaskSubstructureNotify|xproto.EventMaskSubstructureRedirect, string(event.Bytes())).Check()
}
