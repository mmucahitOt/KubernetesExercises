// Environment configuration
export const config = {
  apiUrl: "http://localhost:8081",
  apiTimeout: import.meta.env.VITE_API_TIMEOUT || 5000,
};

// Export individual config values for convenience
export const { apiUrl, apiTimeout } = config;
