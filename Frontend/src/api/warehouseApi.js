/**
 * Purpose: Centralizes browser calls to the FastAPI backend.
 * Runtime role: Gives components and controllers small named functions instead of scattered fetch calls and URL strings.
 * Dependencies: FastAPI endpoints under /health, /api/objects, /api/row-counts, /api/dashboard, /api/spending-categories, and /api/category-rules.
 */

const apiBaseUrl = import.meta.env.VITE_API_BASE_URL ?? "http://localhost:4000";

async function fetchJson(endpointPath) {
  const response = await fetch(`${apiBaseUrl}${endpointPath}`);
  if (!response.ok) {
    throw new Error(`API request failed: ${response.status} ${response.statusText}`);
  }
  return response.json();
}

async function sendJson(endpointPath, payload) {
  const response = await fetch(`${apiBaseUrl}${endpointPath}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  if (!response.ok) {
    throw new Error(`API request failed: ${response.status} ${response.statusText}`);
  }
  return response.json();
}

export function fetchWarehouseHealth() {
  return fetchJson("/health");
}

export function fetchWarehouseRowCounts() {
  return fetchJson("/api/warehouse/row-counts");
}

export function fetchDashboard() {
  return fetchJson("/api/dashboard");
}

export function fetchSpendingCategories() {
  return fetchJson("/api/spending-categories");
}

export function approveCategoryRule(categoryRulePayload) {
  return sendJson("/api/category-rules", categoryRulePayload);
}
