import React from 'react';
import { NavLink, Outlet } from 'react-router-dom';

export default function Layout() {
  return (
    <>
      <nav className="navbar">
        <span className="brand">🏡 SewaCicil</span>
        <NavLink to="/" end>Cari Sewa</NavLink>
        <NavLink to="/bookings">Sewa Saya</NavLink>
        <NavLink to="/housekeeping">Housekeeping</NavLink>
        <NavLink to="/chat">💬 Chat</NavLink>
        <NavLink to="/master-data">🗂️ Master Data</NavLink>
        <NavLink to="/pricing">💹 Pricing</NavLink>
        <NavLink to="/ui-kit">🧩 UI Kit</NavLink>
      </nav>
      <div className="container">
        <Outlet />
      </div>
    </>
  );
}
