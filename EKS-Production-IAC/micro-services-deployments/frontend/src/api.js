// Thin fetch wrapper around the API Gateway. Every request from the browser
// goes to ONE origin (the gateway) - it fans out to the right microservice
// server-side, so the frontend never needs to know user-service lives on a
// different host than order-service.
const BASE_URL = import.meta.env.VITE_API_GATEWAY_URL || "http://localhost:8000";

function authHeaders() {
  const token = localStorage.getItem("access_token");
  return token ? { Authorization: `Bearer ${token}` } : {};
}

async function request(path, { method = "GET", body, auth = true } = {}) {
  const res = await fetch(`${BASE_URL}${path}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(auth ? authHeaders() : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const message = data.detail || data.non_field_errors?.[0] || "Request failed";
    throw new Error(typeof message === "string" ? message : JSON.stringify(message));
  }
  return data;
}

export const api = {
  register: (payload) => request("/api/users/register/", { method: "POST", body: payload, auth: false }),
  login: (payload) => request("/api/users/login/", { method: "POST", body: payload, auth: false }),
  me: () => request("/api/users/me/"),

  listProducts: () => request("/api/products/"),
  listCategories: () => request("/api/categories/"),

  createOrder: (payload) => request("/api/orders/create/", { method: "POST", body: payload }),
  listOrders: () => request("/api/orders/"),

  listNotifications: () => request("/api/notifications/"),

  gatewayHealth: () => request("/health/", { auth: false }),
};
