// Environment configuration
// Use relative paths by default - works with Ingress routing
// Ingress routes:
//   / -> frontend service
//   /todos -> backend service
export const config = {
  apiUrl: import.meta.env.VITE_TODO_API_URL || "",
  backendApiUrl: import.meta.env.VITE_TODO_BACKEND_API_URL || "/todos",
  apiTimeout: import.meta.env.VITE_API_TIMEOUT || 5000,
};

// Export individual config values for convenience
export const { apiUrl, apiTimeout } = config;
