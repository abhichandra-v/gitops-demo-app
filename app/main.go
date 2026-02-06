// Command demo-app is a tiny HTTP service used as the release target in the
// GitOps rollback case study.
package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/prometheus/client_golang/prometheus"
)

// Set at build time with
// -ldflags "-X main.version=... -X main.color=... -X main.faultMode=...".
// Baking the fault into the image means a bad release differs from a good one
// only by its image tag.
var (
	version   = "dev"
	color     = "grey"
	faultMode = "" // baked-in default; the FAULT_MODE env var overrides it
)

func main() {
	addr := ":8080"
	if v := os.Getenv("LISTEN_ADDR"); v != "" {
		addr = v
	}
	hostname, _ := os.Hostname()

	mode := faultMode
	if v, ok := os.LookupEnv("FAULT_MODE"); ok {
		mode = v
	}
	fault, err := newFaultInjector(mode, uint64(time.Now().UnixNano()))
	if err != nil {
		log.Fatal(err)
	}

	srv := &http.Server{
		Addr:              addr,
		Handler:           newServer(config{Version: version, Color: color, Hostname: hostname, Fault: fault}, prometheus.NewRegistry()),
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		log.Printf("demo-app %s listening on %s (fault mode: %q)", version, addr, mode)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("listen: %v", err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Printf("shutdown: %v", err)
	}
}
