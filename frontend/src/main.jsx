import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import Layout from './components/Layout.jsx';
import RentalPlansPage from './pages/RentalPlansPage.jsx';
import BookingDetailPage from './pages/BookingDetailPage.jsx';
import MyBookingsPage from './pages/MyBookingsPage.jsx';
import HousekeepingBoardPage from './pages/HousekeepingBoardPage.jsx';
import './styles.css';

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <BrowserRouter>
      <Routes>
        <Route element={<Layout />}>
          <Route index element={<RentalPlansPage />} />
          <Route path="/bookings" element={<MyBookingsPage />} />
          <Route path="/bookings/:id" element={<BookingDetailPage />} />
          <Route path="/housekeeping" element={<HousekeepingBoardPage />} />
        </Route>
      </Routes>
    </BrowserRouter>
  </React.StrictMode>
);
