import { NavLink } from "react-router-dom";
import { useAuth } from "../context/AuthContext";

const links = [
  { to: "/", label: "Dashboard", icon: "◆" },
  { to: "/products", label: "Products", icon: "▣" },
  { to: "/orders", label: "Orders", icon: "▤" },
  { to: "/notifications", label: "Notifications", icon: "◈" },
];

export default function Sidebar() {
  const { user, logout } = useAuth();
  return (
    <aside className="sidebar">
      <div className="brand">
        <span className="brand-mark">SF</span>
        <span className="brand-name">ShopFlow</span>
      </div>
      <nav className="nav-links">
        {links.map((l) => (
          <NavLink
            key={l.to}
            to={l.to}
            end={l.to === "/"}
            className={({ isActive }) => "nav-link" + (isActive ? " active" : "")}
          >
            <span className="nav-icon">{l.icon}</span>
            {l.label}
          </NavLink>
        ))}
      </nav>
      <div className="sidebar-footer">
        <div className="user-chip">
          <div className="avatar">{user?.username?.[0]?.toUpperCase() ?? "?"}</div>
          <div>
            <div className="user-name">{user?.username}</div>
            <div className="user-email">{user?.email}</div>
          </div>
        </div>
        <button className="btn btn-ghost" onClick={logout}>Sign out</button>
      </div>
    </aside>
  );
}
