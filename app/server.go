package main

import (
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/collectors"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

type config struct {
	Version  string
	Color    string
	Hostname string
	Fault    *faultInjector
}

type versionResponse struct {
	Version   string `json:"version"`
	Color     string `json:"color"`
	Hostname  string `json:"hostname"`
	FaultMode string `json:"fault_mode,omitempty"`
}

type errorResponse struct {
	Error   string `json:"error"`
	Version string `json:"version"`
}

// newServer wires the routes. Only "/" is counted in the request metrics so
// that probe and scrape traffic does not dilute the success rate. Faults are
// injected on "/" only: /healthz keeps passing, as it would for a release that
// starts cleanly but fails real requests.
func newServer(cfg config, reg *prometheus.Registry) http.Handler {
	requests := prometheus.NewCounterVec(prometheus.CounterOpts{
		Name: "http_requests_total",
		Help: "Requests to / by HTTP status code.",
	}, []string{"code"})
	duration := prometheus.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "http_request_duration_seconds",
		Help:    "Duration of requests to / in seconds.",
		Buckets: prometheus.DefBuckets,
	}, []string{"code"})
	info := prometheus.NewGaugeVec(prometheus.GaugeOpts{
		Name: "demo_app_info",
		Help: "Build information; always 1.",
	}, []string{"version"})
	reg.MustRegister(requests, duration, info, collectors.NewGoCollector())
	info.WithLabelValues(cfg.Version).Set(1)

	faultMode := ""
	if cfg.Fault != nil {
		faultMode = cfg.Fault.mode
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/{$}", func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		code := http.StatusOK
		var body any = versionResponse{Version: cfg.Version, Color: cfg.Color, Hostname: cfg.Hostname, FaultMode: faultMode}
		if cfg.Fault.shouldFail() {
			code = http.StatusInternalServerError
			body = errorResponse{Error: "injected fault", Version: cfg.Version}
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(code)
		_ = json.NewEncoder(w).Encode(body)
		label := strconv.Itoa(code)
		requests.WithLabelValues(label).Inc()
		duration.WithLabelValues(label).Observe(time.Since(start).Seconds())
	})
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte("ok\n"))
	})
	mux.Handle("/metrics", promhttp.HandlerFor(reg, promhttp.HandlerOpts{}))
	return mux
}
