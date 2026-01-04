package main

import (
	"flag"
	"log"
	"os"
	"os/signal"
	"syscall"

	"dummysite-controller/pkg/controller"
)

func main() {
	var kubeconfig string
	var namespace string

	flag.StringVar(&kubeconfig, "kubeconfig", "", "path to kubeconfig file (optional, uses in-cluster config if not set)")
	flag.StringVar(&namespace, "namespace", "", "namespace to watch (optional, watches all namespaces if not set)")
	flag.Parse()

	// Create controller
	ctrl, err := controller.NewController(kubeconfig, namespace)
	if err != nil {
		log.Fatalf("Failed to create controller: %v", err)
	}

	// Handle graceful shutdown
	stopCh := make(chan struct{})
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		<-sigCh
		log.Println("Shutting down controller...")
		close(stopCh)
	}()

	// Run controller
	log.Println("Starting DummySite controller...")
	if err := ctrl.Run(stopCh); err != nil {
		log.Fatalf("Controller error: %v", err)
	}
}