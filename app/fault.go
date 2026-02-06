package main

import (
	"fmt"
	"math/rand/v2"
	"regexp"
	"strconv"
	"sync"
)

var errorPctPattern = regexp.MustCompile(`^error-(\d{1,3})pct$`)

// faultInjector decides, per request, whether to fail it. The zero value never
// fails. It simulates a release that passes its health checks but is broken
// for a share of real user requests.
type faultInjector struct {
	mode      string
	errorRate float64

	mu  sync.Mutex
	rng *rand.Rand
}

// newFaultInjector parses a fault mode. Supported: "" (none) and
// "error-<N>pct", which fails N percent of requests with HTTP 500.
func newFaultInjector(mode string, seed uint64) (*faultInjector, error) {
	f := &faultInjector{mode: mode, rng: rand.New(rand.NewPCG(seed, seed^0x9e3779b97f4a7c15))}
	if mode == "" {
		return f, nil
	}
	m := errorPctPattern.FindStringSubmatch(mode)
	if m == nil {
		return nil, fmt.Errorf("unknown FAULT_MODE %q (want \"\" or \"error-<N>pct\")", mode)
	}
	pct, _ := strconv.Atoi(m[1])
	if pct > 100 {
		return nil, fmt.Errorf("FAULT_MODE %q: percentage must be 0-100", mode)
	}
	f.errorRate = float64(pct) / 100
	return f, nil
}

func (f *faultInjector) shouldFail() bool {
	if f == nil || f.errorRate == 0 {
		return false
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.rng.Float64() < f.errorRate
}
