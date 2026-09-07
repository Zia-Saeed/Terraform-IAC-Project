import { useEffect, useState } from "react";
import { api } from "../api";
import { useAuth } from "../context/AuthContext";

export default function Dashboard() {
  const { user } = useAuth();
  const [health, setHealth] = useState(null);
  const [orders, setOrders] = useState([]);
  const [products, setProducts] = useState([]);

  useEffect(() => {
    api.gatewayHealth().then(setHealth).catch(() => setHealth({ downstream: {} }));
    api.listOrders().then((r) => setOrders(r.results ?? r)).catch(() => {});
    api.listProducts().then((r) => setProducts(r.results ?? r)).catch(() => {});
  }, []);

  const totalSpent = orders.reduce((sum, o) => sum + Number(o.total_amount || 0), 0);

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Welcome back, {user?.username} 👋</h1>
          <p className="muted">Here's a live snapshot pulled straight from the microservices behind ShopFlow.</p>
        </div>
      </div>

      <div className="stat-grid">
        <div className="stat-card">
          <div className="stat-label">Total orders</div>
          <div className="stat-value">{orders.length}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Total spent</div>
          <div className="stat-value">${totalSpent.toFixed(2)}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Products in catalog</div>
          <div className="stat-value">{products.length}</div>
        </div>
      </div>

      <div className="card">
        <div className="card-header">
          <h2>System health</h2>
          <span className="muted">via api-gateway /health/</span>
        </div>
        <div className="service-grid">
          {health && Object.entries(health.downstream || {}).map(([name, status]) => (
            <div className="service-pill" key={name}>
              <span className={"dot " + (status === "ok" ? "dot-green" : "dot-red")}></span>
              <span className="service-name">{name.replace(/-/g, " ")}</span>
              <span className="service-status">{status}</span>
            </div>
          ))}
          {!health && <span className="muted">Checking services...</span>}
        </div>
      </div>
    </div>
  );
}
