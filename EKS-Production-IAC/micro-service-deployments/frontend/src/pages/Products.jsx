import { useEffect, useState } from "react";
import { api } from "../api";

export default function Products() {
  const [products, setProducts] = useState([]);
  const [cart, setCart] = useState({});
  const [address, setAddress] = useState("");
  const [placing, setPlacing] = useState(false);
  const [message, setMessage] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.listProducts()
      .then((r) => setProducts(r.results ?? r))
      .catch((e) => setMessage({ type: "error", text: e.message }))
      .finally(() => setLoading(false));
  }, []);

  const addToCart = (id) => setCart({ ...cart, [id]: (cart[id] || 0) + 1 });
  const removeFromCart = (id) => {
    const next = { ...cart };
    if (next[id] > 1) next[id] -= 1;
    else delete next[id];
    setCart(next);
  };

  const cartItems = Object.entries(cart).map(([id, qty]) => {
    const product = products.find((p) => String(p.id) === id);
    return product ? { ...product, qty } : null;
  }).filter(Boolean);

  const cartTotal = cartItems.reduce((sum, i) => sum + Number(i.price) * i.qty, 0);

  const placeOrder = async () => {
    if (!address) {
      setMessage({ type: "error", text: "Add a shipping address first." });
      return;
    }
    setPlacing(true);
    setMessage(null);
    try {
      const payload = {
        shipping_address: address,
        items: cartItems.map((i) => ({ product_id: i.id, quantity: i.qty })),
      };
      const order = await api.createOrder(payload);
      setMessage({ type: "success", text: `Order #${order.id} confirmed — total $${order.total_amount}` });
      setCart({});
      // refresh stock numbers
      const refreshed = await api.listProducts();
      setProducts(refreshed.results ?? refreshed);
    } catch (err) {
      setMessage({ type: "error", text: err.message });
    } finally {
      setPlacing(false);
    }
  };

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Product catalog</h1>
          <p className="muted">Served live by product-service. Placing an order calls order-service, which reserves stock here.</p>
        </div>
      </div>

      {message && <div className={"alert " + (message.type === "error" ? "alert-error" : "alert-success")}>{message.text}</div>}

      <div className="products-layout">
        <div className="product-grid">
          {loading && <div className="muted">Loading products...</div>}
          {!loading && products.length === 0 && (
            <div className="empty-state">No products yet — add some via the Django admin at <code>/admin/</code> on product-service.</div>
          )}
          {products.map((p) => (
            <div className="product-card" key={p.id}>
              <div className="product-card-image">
                {p.image_url ? (
                  <img src={p.image_url} alt={p.name} />
                ) : (
                  <div className="product-card-image-placeholder">No image</div>
                )}
              </div>
              <div className="product-card-top">
                <span className="badge">{p.category_name || "Uncategorized"}</span>
                <span className="stock-badge">{p.stock_quantity} in stock</span>
              </div>
              <h3>{p.name}</h3>
              <p className="muted small">{p.description || "No description provided."}</p>
              <div className="product-card-footer">
                <span className="price">${Number(p.price).toFixed(2)}</span>
                {cart[p.id] ? (
                  <div className="qty-control">
                    <button onClick={() => removeFromCart(p.id)}>-</button>
                    <span>{cart[p.id]}</span>
                    <button onClick={() => addToCart(p.id)}>+</button>
                  </div>
                ) : (
                  <button className="btn btn-secondary" onClick={() => addToCart(p.id)}>Add to cart</button>
                )}
              </div>
            </div>
          ))}
        </div>

        <div className="cart-panel">
          <h2>Your cart</h2>
          {cartItems.length === 0 && <p className="muted small">Cart is empty. Add products to place an order.</p>}
          {cartItems.map((i) => (
            <div className="cart-row" key={i.id}>
              <span>{i.name} × {i.qty}</span>
              <span>${(i.price * i.qty).toFixed(2)}</span>
            </div>
          ))}
          {cartItems.length > 0 && (
            <>
              <div className="cart-total">
                <span>Total</span>
                <span>${cartTotal.toFixed(2)}</span>
              </div>
              <label className="small">Shipping address
                <input value={address} onChange={(e) => setAddress(e.target.value)} placeholder="123 Main St, Riyadh" />
              </label>
              <button className="btn btn-primary full" disabled={placing} onClick={placeOrder}>
                {placing ? "Placing order..." : "Place order"}
              </button>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
