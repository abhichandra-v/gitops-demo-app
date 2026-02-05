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

// Set at build time with -ldflags "-X main.version=... -X main.color=...".
var (
	version = "dev"
	color   = "grey"
)

func main() {
	addr := ":8080"
	if v := os.Getenv("LISTEN_ADDR"); v != "" {
		addr = v
	}
	hostname, _ := os.Hostname()

	srv := &http.Server{
		Addr:              addr,
		Handler:           newServer(config{Version: version, Color: color, Hostname: hostname}, prometheus.NewRegistry()),
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		log.Printf("demo-app %s listening on %s", version, addr)
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
