import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";

export default function Register() {
  const { register } = useAuth();
  const navigate = useNavigate();
  const [form, setForm] = useState({ username: "", email: "", password: "", company_name: "", phone_number: "" });
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const update = (key) => (e) => setForm({ ...form, [key]: e.target.value });

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      await register(form);
      navigate("/");
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="auth-screen">
      <div className="auth-card">
        <div className="brand auth-brand">
          <span className="brand-mark">SF</span>
          <span className="brand-name">ShopFlow</span>
        </div>
        <h1>Create your account</h1>
        <p className="muted">One account, backed by five microservices working together.</p>
        {error && <div className="alert alert-error">{error}</div>}
        <form onSubmit={submit} className="form">
          <label>Username
            <input value={form.username} onChange={update("username")} required />
          </label>
          <label>Email
            <input type="email" value={form.email} onChange={update("email")} required />
          </label>
          <label>Password
            <input type="password" value={form.password} onChange={update("password")} required />
          </label>
          <label>Company (optional)
            <input value={form.company_name} onChange={update("company_name")} />
          </label>
          <button className="btn btn-primary" disabled={loading}>{loading ? "Creating..." : "Create account"}</button>
        </form>
        <p className="muted center">Already have an account? <Link to="/login">Sign in</Link></p>
      </div>
    </div>
  );
}
