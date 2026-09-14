import { Navigate, Route, Routes } from "react-router-dom";
import Sidebar from "./components/Sidebar";
import ProtectedRoute from "./components/ProtectedRoute";
import { useAuth } from "./context/AuthContext";
import Login from "./pages/Login";
import Register from "./pages/Register";
import Dashboard from "./pages/Dashboard";
import Products from "./pages/Products";
import Orders from "./pages/Orders";
import Notifications from "./pages/Notifications";

function Shell({ children }) {
  return (
    <div className="app-shell">
      <Sidebar />
      <main className="main-content">{children}</main>
    </div>
  );
}

export default function App() {
  const { user, loading } = useAuth();

  if (loading) return <div className="page-loading">Loading ShopFlow...</div>;

  return (
    <Routes>
      <Route path="/login" element={user ? <Navigate to="/" /> : <Login />} />
      <Route path="/register" element={user ? <Navigate to="/" /> : <Register />} />
      <Route path="/" element={<ProtectedRoute><Shell><Dashboard /></Shell></ProtectedRoute>} />
      <Route path="/products" element={<ProtectedRoute><Shell><Products /></Shell></ProtectedRoute>} />
      <Route path="/orders" element={<ProtectedRoute><Shell><Orders /></Shell></ProtectedRoute>} />
      <Route path="/notifications" element={<ProtectedRoute><Shell><Notifications /></Shell></ProtectedRoute>} />
    </Routes>
  );
}
