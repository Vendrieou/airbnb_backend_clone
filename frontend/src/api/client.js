import axios from 'axios';

// Vite proxy meneruskan /rental_plans, /housekeeping dst ke Rails :3000 saat dev.
export const http = axios.create({ baseURL: '/' });

http.interceptors.request.use((cfg) => {
  const token = localStorage.getItem('token');
  if (token) cfg.headers.Authorization = `Bearer ${token}`;
  return cfg;
});

// ---- Rental Plans (harian / mingguan / bulanan + cicilan) ----
export const listRentalPlans = ({ period, installments } = {}) =>
  http.get('/rental_plans', { params: { period, installments } }).then(r => r.data);

export const installmentEstimate = (planId, params) =>
  http.get(`/rental_plans/${planId}/installment_estimate`, { params }).then(r => r.data);

export const createRentalBooking = (planId, body, idempotencyKey) =>
  http.post(`/rental_plans/${planId}/bookings`, body, {
    headers: { 'Idempotency-Key': idempotencyKey },
  }).then(r => r.data);

export const listMyRentalBookings = () =>
  http.get('/rental_bookings').then(r => r.data);

export const getRentalBooking = (id) =>
  http.get(`/rental_bookings/${id}`).then(r => r.data);

export const payRentalBooking = (id, body) =>
  http.post(`/rental_bookings/${id}/pay`, body).then(r => r.data);

export const cancelRentalBooking = (id) =>
  http.post(`/rental_bookings/${id}/cancel`).then(r => r.data);

// ---- Housekeeping Kanban ----
export const listBoards = () => http.get('/housekeeping/boards').then(r => r.data);
export const getBoard = (id) => http.get(`/housekeeping/boards/${id}`).then(r => r.data);
export const advanceTask = (id) => http.post(`/housekeeping/tasks/${id}/advance`).then(r => r.data);
export const uploadTaskImage = (id, file) => {
  const fd = new FormData();
  fd.append('image', file);
  return http.post(`/housekeeping/tasks/${id}/upload`, fd, {
    headers: { 'Content-Type': 'multipart/form-data' },
  }).then(r => r.data);
};

export const formatIDR = (n) =>
  new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(n || 0);

export const PERIOD_LABEL = { daily: 'Harian', weekly: 'Mingguan', monthly: 'Bulanan' };
