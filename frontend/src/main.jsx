import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import Layout from './components/Layout.jsx';
import RentalPlansPage from './pages/RentalPlansPage.jsx';
import BookingDetailPage from './pages/BookingDetailPage.jsx';
import MyBookingsPage from './pages/MyBookingsPage.jsx';
import HousekeepingBoardPage from './pages/HousekeepingBoardPage.jsx';
import ChatPage from './pages/ChatPage.jsx';
import MasterDataPage from './pages/MasterDataPage.jsx';
import PricingMatrixPage from './pages/PricingMatrixPage.tsx';
import UiKitPage from './pages/UiKitPage.tsx';
import { Toaster } from '@/components/ui/sonner';
import './index.css';
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
          <Route path="/chat" element={<ChatPage />} />
          <Route path="/chat/:id" element={<ChatPage />} />
          <Route path="/master-data" element={<MasterDataPage />} />
          <Route path="/pricing" element={<PricingMatrixPage />} />
          <Route path="/ui-kit" element={<UiKitPage />} />
        </Route>
      </Routes>
      <Toaster richColors position="top-right" />
    </BrowserRouter>
  </React.StrictMode>
);
