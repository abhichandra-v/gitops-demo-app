package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/testutil"
)

func newTestServer(t *testing.T, mode string) (http.Handler, *prometheus.Registry) {
	t.Helper()
	fault, err := newFaultInjector(mode, 42)
	if err != nil {
		t.Fatalf("newFaultInjector(%q): %v", mode, err)
	}
	reg := prometheus.NewRegistry()
	return newServer(config{Version: "v9.9.9", Color: "teal", Hostname: "test", Fault: fault}, reg), reg
}

func get(h http.Handler, path string) *httptest.ResponseRecorder {
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, path, nil))
	return rec
}

func TestRootReturnsVersionJSON(t *testing.T) {
	h, _ := newTestServer(t, "")
	rec := get(h, "/")
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	var got versionResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &got); err != nil {
		t.Fatalf("body is not JSON: %v", err)
	}
	if got.Version != "v9.9.9" || got.Color != "teal" || got.Hostname != "test" {
		t.Errorf("unexpected body: %+v", got)
	}
}

func TestUnknownPathIsNotFound(t *testing.T) {
	h, _ := newTestServer(t, "")
	if rec := get(h, "/nope"); rec.Code != http.StatusNotFound {
		t.Errorf("status = %d, want 404", rec.Code)
	}
}

func TestNoFaultModeNeverFails(t *testing.T) {
	h, _ := newTestServer(t, "")
	for i := 0; i < 2000; i++ {
		if rec := get(h, "/"); rec.Code != http.StatusOK {
			t.Fatalf("request %d: status = %d, want 200", i, rec.Code)
		}
	}
}

func TestFaultModeFailsAboutFortyPercent(t *testing.T) {
	h, _ := newTestServer(t, "error-40pct")
	const n = 10000
	failed := 0
	for i := 0; i < n; i++ {
		switch rec := get(h, "/"); rec.Code {
		case http.StatusInternalServerError:
			failed++
		case http.StatusOK:
		default:
			t.Fatalf("unexpected status %d", rec.Code)
		}
	}
	rate := float64(failed) / n
	if rate < 0.37 || rate > 0.43 {
		t.Errorf("error rate = %.3f over %d requests, want about 0.40", rate, n)
	}
}

func TestFaultModeDoesNotAffectHealthz(t *testing.T) {
	h, _ := newTestServer(t, "error-100pct")
	for i := 0; i < 50; i++ {
		if rec := get(h, "/healthz"); rec.Code != http.StatusOK {
			t.Fatalf("healthz status = %d, want 200", rec.Code)
		}
	}
	if rec := get(h, "/"); rec.Code != http.StatusInternalServerError {
		t.Errorf("/ status = %d, want 500 with error-100pct", rec.Code)
	}
}

func TestFaultModeParsing(t *testing.T) {
	cases := []struct {
		mode    string
		rate    float64
		wantErr bool
	}{
		{"", 0, false},
		{"error-40pct", 0.40, false},
		{"error-0pct", 0, false},
		{"error-100pct", 1, false},
		{"error-101pct", 0, true},
		{"latency-2s", 0, true},
		{"error-40", 0, true},
	}
	for _, c := range cases {
		f, err := newFaultInjector(c.mode, 1)
		if (err != nil) != c.wantErr {
			t.Errorf("mode %q: err = %v, wantErr = %v", c.mode, err, c.wantErr)
			continue
		}
		if err == nil && f.errorRate != c.rate {
			t.Errorf("mode %q: rate = %v, want %v", c.mode, f.errorRate, c.rate)
		}
	}
}

func TestMetricsCountRequestsByStatusCode(t *testing.T) {
	h, reg := newTestServer(t, "error-40pct")
	const n = 500
	want := map[string]float64{}
	for i := 0; i < n; i++ {
		if get(h, "/").Code == http.StatusOK {
			want["200"]++
		} else {
			want["500"]++
		}
	}
	// Probe traffic must not be counted.
	get(h, "/healthz")

	expected := "# HELP http_requests_total Requests to / by HTTP status code.\n" +
		"# TYPE http_requests_total counter\n" +
		"http_requests_total{code=\"200\"} " + trimFloat(want["200"]) + "\n" +
		"http_requests_total{code=\"500\"} " + trimFloat(want["500"]) + "\n"
	if err := testutil.GatherAndCompare(reg, strings.NewReader(expected), "http_requests_total"); err != nil {
		t.Error(err)
	}
	if want["200"]+want["500"] != n || want["500"] == 0 {
		t.Errorf("counts do not add up: %v", want)
	}
}

func TestMetricsEndpointExposesExpectedSeries(t *testing.T) {
	h, _ := newTestServer(t, "")
	get(h, "/")
	body := get(h, "/metrics").Body.String()
	for _, want := range []string{
		`http_requests_total{code="200"} 1`,
		`http_request_duration_seconds_count{code="200"} 1`,
		`demo_app_info{version="v9.9.9"} 1`,
	} {
		if !strings.Contains(body, want) {
			t.Errorf("/metrics is missing %q", want)
		}
	}
}

func trimFloat(f float64) string {
	b, _ := json.Marshal(f)
	return string(b)
}
