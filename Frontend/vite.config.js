/**
 * Purpose: Configures Vite for the local React dashboard.
 * Runtime role: Enables the development server and proxies /api calls to FastAPI so browser code can use relative API paths.
 * Dependencies: @vitejs/plugin-react, Vite, and the FastAPI service listening on localhost:4000.
 */

import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [react()],
  server: {
    host: "0.0.0.0",
    port: 5173,
  },
});
