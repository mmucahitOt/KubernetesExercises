# DummySite Controller

A Kubernetes controller that creates HTML copies of websites from any URL using Custom Resource Definitions (CRD).

## Overview

This project implements a custom Kubernetes controller that:

- Defines a `DummySite` custom resource
- Watches for `DummySite` resources
- Fetches HTML content from specified URLs
- Creates Kubernetes resources (ConfigMap, Deployment, Service) to serve the HTML
- Updates the `DummySite` status with the service URL
