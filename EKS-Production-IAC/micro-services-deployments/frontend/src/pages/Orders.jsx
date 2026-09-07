import { useEffect, useState } from "react";
import { api } from "../api";

const statusColor = {
  CONFIRMED: "dot-green",
  PENDING: "dot-yellow",
  FAILED: "dot-red",
  CANCELLED: "dot-red",
};

export default function Orders() {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    api.listOrders()
      .then((r) => setOrders(r.results ?? r))
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  }, []);

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Order history</h1>
          <p className="muted">Owned by order-service — each order stores a snapshot of items priced at purchase time.</p>
        </div>
      </div>

      {error && <div className="alert alert-error">{error}</div>}
      {loading && <div className="muted">Loading orders...</div>}
      {!loading && orders.length === 0 && <div className="empty-state">No orders yet — place one from the Products page.</div>}

      <div className="order-list">
        {orders.map((o) => (
          <div className="order-card" key={o.id}>
            <div className="order-card-header">
              <div>
                <strong>Order #{o.id}</strong>
                <span className="muted small"> · {new Date(o.created_at).toLocaleString()}</span>
              </div>
              <div className="status-chip">
                <span className={"dot " + (statusColor[o.status] || "dot-yellow")}></span>
                {o.status}
              </div>
            </div>
            <div className="order-items">
              {o.items.map((it) => (
                <div className="order-item-row" key={it.id}>
                  <span>{it.product_name} × {it.quantity}</span>
                  <span>${Number(it.subtotal).toFixed(2)}</span>
                </div>
              ))}
            </div>
            <div className="order-card-footer">
              <span className="muted small">Ship to: {o.shipping_address}</span>
              <strong>${Number(o.total_amount).toFixed(2)}</strong>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
