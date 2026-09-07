import { useEffect, useState } from "react";
import { api } from "../api";

export default function Notifications() {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    api.listNotifications()
      .then((r) => setItems(r.results ?? r))
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  }, []);

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Notifications</h1>
          <p className="muted">Sent by notification-service whenever order-service confirms an order.</p>
        </div>
      </div>

      {error && <div className="alert alert-error">{error}</div>}
      {loading && <div className="muted">Loading notifications...</div>}
      {!loading && items.length === 0 && <div className="empty-state">Nothing yet — place an order to trigger one.</div>}

      <div className="notif-list">
        {items.map((n) => (
          <div className="notif-row" key={n.id}>
            <span className="notif-icon">✉</span>
            <div>
              <div>{n.message}</div>
              <div className="muted small">{new Date(n.created_at).toLocaleString()} · {n.event_type}</div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
