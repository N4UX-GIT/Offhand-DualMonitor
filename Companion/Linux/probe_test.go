package main

import (
	"context"
	"errors"
	"slices"
	"testing"
)

var pair = []monitor{{"left", rect{-1920, 0, 1920, 1080}}, {"right", rect{0, 100, 1920, 1080}}}

func TestPlanAndClass(t *testing.T) {
	want := rect{-1856, 164, 3712, 852}
	three := append(slices.Clone(pair), monitor{"top", rect{0, -1000, 1600, 1100}})
	r, err := plan(three, []string{"right", "left"})
	if err != nil || r != want {
		t.Fatalf("explicit pair: %v %v", r, err)
	}
	for _, names := range [][]string{nil, {"top", "right"}, {"left", "left"}, {"left", "missing"}} {
		if _, err := plan(three, names); err == nil {
			t.Errorf("unexpectedly accepted %v", names)
		}
	}
	for raw, ok := range map[string]bool{"wow\x00WowB.exe\x00": true, "WowClassicEra.exe": true, "Battle.net.exe": false, "NotWow.exe": false} {
		if (wowClass([]byte(raw)) != "") != ok {
			t.Errorf("wrong class result for %q", raw)
		}
	}
}

type fakeDesktop struct {
	box          rect
	requests     []rect
	apply        func(rect, int) rect
	reads        int
	userMoveAt   int
	stateChanged bool
}

func (f *fakeDesktop) monitors() ([]monitor, error) { return pair, nil }
func (f *fakeDesktop) boundsFor(target) (rect, error) {
	f.reads++
	if f.userMoveAt == f.reads {
		f.box.X += 15
	}
	return f.box, nil
}
func (f *fakeDesktop) ordinary(target) error {
	if f.stateChanged {
		return errors.New("state changed")
	}
	return nil
}
func (f *fakeDesktop) move(_ target, r rect) error {
	f.requests = append(f.requests, r)
	f.box = f.apply(r, len(f.requests))
	return nil
}

func TestTrial(t *testing.T) {
	original := rect{20, 120, 800, 600}
	desired, _ := plan(pair, nil)
	for _, c := range []struct {
		name         string
		first        rect
		manual       bool
		stateChanged bool
		failRestore  bool
		ok           bool
		moves        int
	}{
		{"verified", desired, false, false, false, true, 2},
		{"refused", original, false, false, false, false, 1},
		{"clamped", rect{20, 120, 1200, 700}, false, false, false, false, 2},
		{"later user move", desired, true, false, false, false, 1},
		{"new window state", desired, false, true, false, false, 1},
		{"restore refused", desired, false, false, true, false, 2},
	} {
		t.Run(c.name, func(t *testing.T) {
			f := &fakeDesktop{box: original, stateChanged: c.stateChanged}
			if c.manual {
				f.userMoveAt = 4
			}
			f.apply = func(r rect, n int) rect {
				if n == 1 || c.failRestore {
					return c.first
				}
				return r
			}
			err := trial(context.Background(), f, target{}, pair, original, desired, 0, 0)
			if (err == nil) != c.ok || len(f.requests) != c.moves || (c.moves == 2 && f.requests[1] != original) {
				t.Fatalf("err=%v moves=%v", err, f.requests)
			}
		})
	}
}
