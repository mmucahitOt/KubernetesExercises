package controller

import (
	"context"
	"fmt"
	"io"
	"log"
	"net/http"
	"time"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime/schema"
	"k8s.io/apimachinery/pkg/util/intstr"
	"k8s.io/apimachinery/pkg/util/wait"
	"k8s.io/client-go/dynamic"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
)

// Controller manages DummySite resources
type Controller struct {
	dynamicClient dynamic.Interface
	clientset     kubernetes.Interface
	namespace     string
	gvr           schema.GroupVersionResource
}

// NewController creates a new controller instance
func NewController(kubeconfig, namespace string) (*Controller, error) {
	var config *rest.Config
	var err error

	if kubeconfig == "" {
		// Use in-cluster config
		config, err = rest.InClusterConfig()
		if err != nil {
			return nil, fmt.Errorf("failed to get in-cluster config: %w", err)
		}
	} else {
		// Use kubeconfig file
		config, err = clientcmd.BuildConfigFromFlags("", kubeconfig)
		if err != nil {
			return nil, fmt.Errorf("failed to build config from kubeconfig: %w", err)
		}
	}

	dynamicClient, err := dynamic.NewForConfig(config)
	if err != nil {
		return nil, fmt.Errorf("failed to create dynamic client: %w", err)
	}

	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		return nil, fmt.Errorf("failed to create clientset: %w", err)
	}

	gvr := schema.GroupVersionResource{
		Group:    "example.com",
		Version:  "v1",
		Resource: "dummysites",
	}

	return &Controller{
		dynamicClient: dynamicClient,
		clientset:     clientset,
		namespace:     namespace,
		gvr:           gvr,
	}, nil
}

// Run starts the controller
func (c *Controller) Run(stopCh <-chan struct{}) error {
	log.Println("Starting DummySite controller...")

	// Create context for watch
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Start watch loop
	go func() {
		<-stopCh
		cancel()
	}()

	// Watch for DummySite resources
	var resourceInterface dynamic.ResourceInterface
	if c.namespace == "" {
		resourceInterface = c.dynamicClient.Resource(c.gvr)
	} else {
		resourceInterface = c.dynamicClient.Resource(c.gvr).Namespace(c.namespace)
	}

	// Watch loop with reconnection
	for {
		// Watch loop
		watch, err := resourceInterface.Watch(ctx, metav1.ListOptions{})
		if err != nil {
			return fmt.Errorf("failed to watch DummySite resources: %w", err)
		}

		log.Println("Watching for DummySite resources...")

		// Process events
		func() {
			defer watch.Stop()
			for {
				select {
				case <-stopCh:
					log.Println("Stopping controller...")
					return
				case event, ok := <-watch.ResultChan():
					if !ok {
						// Watch channel closed, reconnect
						log.Println("Watch channel closed, reconnecting...")
						return
					}

					// Handle event
					if err := c.handleEvent(event.Object.(*unstructured.Unstructured)); err != nil {
						log.Printf("Error handling event: %v", err)
					}
				}
			}
		}()

		// Check if we should exit
		select {
		case <-stopCh:
			return nil
		default:
			// Reconnect after a short delay
			time.Sleep(2 * time.Second)
		}
	}
}

// handleEvent processes a DummySite event
func (c *Controller) handleEvent(obj *unstructured.Unstructured) error {
	name := obj.GetName()
	namespace := obj.GetNamespace()
	if namespace == "" {
		namespace = "default"
	}

	log.Printf("Processing DummySite: %s/%s", namespace, name)

	// Extract spec
	spec, found, err := unstructured.NestedMap(obj.Object, "spec")
	if err != nil || !found {
		return fmt.Errorf("failed to get spec: %w", err)
	}

	websiteURL, ok := spec["website_url"].(string)
	if !ok || websiteURL == "" {
		return fmt.Errorf("website_url is missing or invalid")
	}

	// Reconcile: fetch HTML and create resources
	if err := c.reconcile(namespace, name, websiteURL); err != nil {
		return fmt.Errorf("reconciliation failed: %w", err)
	}

	return nil
}

// reconcile ensures resources exist for a DummySite
func (c *Controller) reconcile(namespace, name, websiteURL string) error {
	log.Printf("Reconciling DummySite %s/%s with URL: %s", namespace, name, websiteURL)

	// 1. Fetch HTML from URL
	html, err := c.fetchHTML(websiteURL)
	if err != nil {
		return fmt.Errorf("failed to fetch HTML: %w", err)
	}

	// 2. Create or update ConfigMap
	if err := c.createOrUpdateConfigMap(namespace, name, html); err != nil {
		return fmt.Errorf("failed to create ConfigMap: %w", err)
	}

	// 3. Create or update Deployment
	if err := c.createOrUpdateDeployment(namespace, name); err != nil {
		return fmt.Errorf("failed to create Deployment: %w", err)
	}

	// 4. Create or update Service
	serviceURL, err := c.createOrUpdateService(namespace, name)
	if err != nil {
		return fmt.Errorf("failed to create Service: %w", err)
	}

	// 5. Update DummySite status
	if err := c.updateStatus(namespace, name, true, serviceURL); err != nil {
		return fmt.Errorf("failed to update status: %w", err)
	}

	log.Printf("Successfully reconciled DummySite %s/%s", namespace, name)
	return nil
}

// fetchHTML fetches HTML content from a URL
func (c *Controller) fetchHTML(url string) (string, error) {
	client := &http.Client{
		Timeout: 30 * time.Second,
	}

	// Create request with headers
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}

	// Add realistic browser headers to avoid 403 errors
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
	req.Header.Set("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8")
	req.Header.Set("Accept-Language", "en-US,en;q=0.9")
	req.Header.Set("Accept-Encoding", "gzip, deflate, br")
	req.Header.Set("Connection", "keep-alive")
	req.Header.Set("Upgrade-Insecure-Requests", "1")

	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to fetch URL: %w", err)
	}
	defer resp.Body.Close()

	// Log response details for debugging
	if resp.StatusCode != http.StatusOK {
		// Read error body for more details
		body, _ := io.ReadAll(resp.Body)
		log.Printf("HTTP Error %d for URL %s: %s", resp.StatusCode, url, string(body[:min(200, len(body))]))
		return "", fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response: %w", err)
	}

	return string(body), nil
}

// createOrUpdateConfigMap creates or updates a ConfigMap with HTML content
func (c *Controller) createOrUpdateConfigMap(namespace, name, html string) error {
	cmName := fmt.Sprintf("dummysite-%s-html", name)

	cm := &corev1.ConfigMap{
		ObjectMeta: metav1.ObjectMeta{
			Name:      cmName,
			Namespace: namespace,
			Labels: map[string]string{
				"app":       "dummysite",
				"dummysite": name,
			},
		},
		Data: map[string]string{
			"index.html": html,
		},
	}

	// Try to get existing ConfigMap
	_, err := c.clientset.CoreV1().ConfigMaps(namespace).Get(context.TODO(), cmName, metav1.GetOptions{})
	if err != nil {
		// Create if not exists
		_, err = c.clientset.CoreV1().ConfigMaps(namespace).Create(context.TODO(), cm, metav1.CreateOptions{})
		if err != nil {
			return fmt.Errorf("failed to create ConfigMap: %w", err)
		}
		log.Printf("Created ConfigMap: %s/%s", namespace, cmName)
	} else {
		// Update if exists
		_, err = c.clientset.CoreV1().ConfigMaps(namespace).Update(context.TODO(), cm, metav1.UpdateOptions{})
		if err != nil {
			return fmt.Errorf("failed to update ConfigMap: %w", err)
		}
		log.Printf("Updated ConfigMap: %s/%s", namespace, cmName)
	}

	return nil
}

// createOrUpdateDeployment creates or updates a Deployment to serve HTML
func (c *Controller) createOrUpdateDeployment(namespace, name string) error {
	cmName := fmt.Sprintf("dummysite-%s-html", name)
	deployName := fmt.Sprintf("dummysite-%s", name)

	replicas := int32(1)

	deployment := &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Name:      deployName,
			Namespace: namespace,
			Labels: map[string]string{
				"app":       "dummysite",
				"dummysite": name,
			},
		},
		Spec: appsv1.DeploymentSpec{
			Replicas: &replicas,
			Selector: &metav1.LabelSelector{
				MatchLabels: map[string]string{
					"app":       "dummysite",
					"dummysite": name,
				},
			},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Labels: map[string]string{
						"app":       "dummysite",
						"dummysite": name,
					},
				},
				Spec: corev1.PodSpec{
					Containers: []corev1.Container{
						{
							Name:  "nginx",
							Image: "nginx:alpine",
							Ports: []corev1.ContainerPort{
								{
									ContainerPort: 80,
									Name:          "http",
								},
							},
							VolumeMounts: []corev1.VolumeMount{
								{
									Name:      "html",
									MountPath: "/usr/share/nginx/html",
								},
							},
						},
					},
					Volumes: []corev1.Volume{
						{
							Name: "html",
							VolumeSource: corev1.VolumeSource{
								ConfigMap: &corev1.ConfigMapVolumeSource{
									LocalObjectReference: corev1.LocalObjectReference{
										Name: cmName,
									},
								},
							},
						},
					},
				},
			},
		},
	}

	// Try to get existing Deployment
	_, err := c.clientset.AppsV1().Deployments(namespace).Get(context.TODO(), deployName, metav1.GetOptions{})
	if err != nil {
		// Create if not exists
		_, err = c.clientset.AppsV1().Deployments(namespace).Create(context.TODO(), deployment, metav1.CreateOptions{})
		if err != nil {
			return fmt.Errorf("failed to create Deployment: %w", err)
		}
		log.Printf("Created Deployment: %s/%s", namespace, deployName)
	} else {
		// Update if exists
		_, err = c.clientset.AppsV1().Deployments(namespace).Update(context.TODO(), deployment, metav1.UpdateOptions{})
		if err != nil {
			return fmt.Errorf("failed to update Deployment: %w", err)
		}
		log.Printf("Updated Deployment: %s/%s", namespace, deployName)
	}

	return nil
}

// createOrUpdateService creates or updates a Service to expose the Deployment
func (c *Controller) createOrUpdateService(namespace, name string) (string, error) {
	serviceName := fmt.Sprintf("dummysite-%s", name)

	service := &corev1.Service{
		ObjectMeta: metav1.ObjectMeta{
			Name:      serviceName,
			Namespace: namespace,
			Labels: map[string]string{
				"app":       "dummysite",
				"dummysite": name,
			},
		},
		Spec: corev1.ServiceSpec{
			Selector: map[string]string{
				"app":       "dummysite",
				"dummysite": name,
			},
			Ports: []corev1.ServicePort{
				{
					Port:       80,
					TargetPort: intstr.FromInt(80),
					Protocol:   corev1.ProtocolTCP,
					Name:       "http",
				},
			},
			Type: corev1.ServiceTypeClusterIP,
		},
	}

	// Try to get existing Service
	_, err := c.clientset.CoreV1().Services(namespace).Get(context.TODO(), serviceName, metav1.GetOptions{})
	if err != nil {
		// Create if not exists
		_, err = c.clientset.CoreV1().Services(namespace).Create(context.TODO(), service, metav1.CreateOptions{})
		if err != nil {
			return "", fmt.Errorf("failed to create Service: %w", err)
		}
		log.Printf("Created Service: %s/%s", namespace, serviceName)
	} else {
		// Update if exists
		_, err = c.clientset.CoreV1().Services(namespace).Update(context.TODO(), service, metav1.UpdateOptions{})
		if err != nil {
			return "", fmt.Errorf("failed to update Service: %w", err)
		}
		log.Printf("Updated Service: %s/%s", namespace, serviceName)
	}

	// Wait for service to get an IP
	var serviceURL string
	err = wait.PollImmediate(1*time.Second, 30*time.Second, func() (bool, error) {
		svc, err := c.clientset.CoreV1().Services(namespace).Get(context.TODO(), serviceName, metav1.GetOptions{})
		if err != nil {
			return false, err
		}
		if svc.Spec.ClusterIP != "" {
			serviceURL = fmt.Sprintf("http://%s.%s.svc.cluster.local", serviceName, namespace)
			return true, nil
		}
		return false, nil
	})

	if err != nil {
		return "", fmt.Errorf("service did not get ClusterIP: %w", err)
	}

	return serviceURL, nil
}

// updateStatus updates the DummySite status
func (c *Controller) updateStatus(namespace, name string, ready bool, url string) error {
	resourceInterface := c.dynamicClient.Resource(c.gvr).Namespace(namespace)

	// Retry logic in case resource was deleted/recreated
	var obj *unstructured.Unstructured
	var err error

	// Retry up to 3 times with exponential backoff
	for i := 0; i < 3; i++ {
		obj, err = resourceInterface.Get(context.TODO(), name, metav1.GetOptions{})
		if err == nil {
			break
		}
		if i < 2 {
			time.Sleep(time.Duration(i+1) * time.Second)
			continue
		}
		return fmt.Errorf("failed to get DummySite after retries: %w", err)
	}

	// Update status
	status := map[string]interface{}{
		"ready": ready,
		"url":   url,
	}
	if err := unstructured.SetNestedField(obj.Object, status, "status"); err != nil {
		return fmt.Errorf("failed to set status: %w", err)
	}

	// Try UpdateStatus first, fallback to Update if it fails
	_, err = resourceInterface.UpdateStatus(context.TODO(), obj, metav1.UpdateOptions{})
	if err != nil {
		// If UpdateStatus fails, try regular Update
		_, err = resourceInterface.Update(context.TODO(), obj, metav1.UpdateOptions{})
		if err != nil {
			return fmt.Errorf("failed to update status: %w", err)
		}
	}

	log.Printf("Updated status for DummySite %s/%s: ready=%v, url=%s", namespace, name, ready, url)
	return nil
}
