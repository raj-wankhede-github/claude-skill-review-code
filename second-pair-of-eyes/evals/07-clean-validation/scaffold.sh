#!/usr/bin/env bash
# Builds the fixture repository in the (empty) run workspace.
set -euo pipefail

init_repo() {
  git init -q -b main .
  git config user.name "Eval Author"
  git config user.email "eval@example.com"
  git config commit.gpgsign false
  git config core.autocrlf false
}

# commit "<message>" — stage everything and commit
commit() {
  git add -A
  git commit -q -m "$1"
}

# write <path> — write stdin to path, creating parent directories
write() {
  mkdir -p "$(dirname "$1")"
  cat > "$1"
}

init_repo

write go.mod <<'GO'
module example.com/throttle

go 1.22
GO

write limiter/limiter.go <<'GO'
package limiter

import "time"

// Limiter spaces calls evenly at a fixed rate.
type Limiter struct {
	interval time.Duration
}

// New returns a limiter allowing perSecond calls per second.
func New(perSecond int) *Limiter {
	return &Limiter{interval: time.Second / time.Duration(perSecond)}
}

// Interval is the minimum spacing between calls.
func (l *Limiter) Interval() time.Duration { return l.interval }
GO

write limiter/limiter_test.go <<'GO'
package limiter

import (
	"testing"
	"time"
)

func TestNewInterval(t *testing.T) {
	if got := New(4).Interval(); got != 250*time.Millisecond {
		t.Fatalf("interval = %v, want 250ms", got)
	}
}
GO

write main.go <<'GO'
package main

import (
	"flag"
	"fmt"

	"example.com/throttle/limiter"
)

func main() {
	rate := flag.Int("rate", 10, "requests per second")
	flag.Parse()
	l := limiter.New(*rate)
	fmt.Println("interval:", l.Interval())
}
GO
commit "Fixed-rate limiter CLI"

# --- the change under review (uncommitted): reject non-positive rates instead of panicking ---
write limiter/limiter.go <<'GO'
package limiter

import (
	"fmt"
	"time"
)

// Limiter spaces calls evenly at a fixed rate.
type Limiter struct {
	interval time.Duration
}

// New returns a limiter allowing perSecond calls per second.
// It returns an error if perSecond is not positive (previously this panicked with a division by zero for 0).
func New(perSecond int) (*Limiter, error) {
	if perSecond <= 0 {
		return nil, fmt.Errorf("limiter: perSecond must be positive, got %d", perSecond)
	}
	return &Limiter{interval: time.Second / time.Duration(perSecond)}, nil
}

// Interval is the minimum spacing between calls.
func (l *Limiter) Interval() time.Duration { return l.interval }
GO

write limiter/limiter_test.go <<'GO'
package limiter

import (
	"testing"
	"time"
)

func TestNewInterval(t *testing.T) {
	l, err := New(4)
	if err != nil {
		t.Fatal(err)
	}
	if got := l.Interval(); got != 250*time.Millisecond {
		t.Fatalf("interval = %v, want 250ms", got)
	}
}

func TestNewRejectsNonPositive(t *testing.T) {
	for _, rate := range []int{0, -1} {
		if _, err := New(rate); err == nil {
			t.Fatalf("New(%d) returned nil error", rate)
		}
	}
}
GO

write main.go <<'GO'
package main

import (
	"flag"
	"fmt"
	"os"

	"example.com/throttle/limiter"
)

func main() {
	rate := flag.Int("rate", 10, "requests per second")
	flag.Parse()
	l, err := limiter.New(*rate)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	fmt.Println("interval:", l.Interval())
}
GO
