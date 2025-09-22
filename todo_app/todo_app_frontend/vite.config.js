import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";

// https://vite.dev/config/
export default defineConfig(({ command, mode }) => {
  // Load env file based on `mode` in the current working directory.
  const env = loadEnv(mode, process.cwd(), "");

  return {
    plugins: [react()],

    // Environment variables configuration
    define: {
      __APP_VERSION__: JSON.stringify(process.env.npm_package_version),
    },

    // Server configuration
    server: {
      port: 3000,
      host: true,
    },

    // Build configuration
    build: {
      outDir: "dist",
      sourcemap: mode === "development",
    },

    // Environment variables
    envPrefix: "VITE_",
  };
});
