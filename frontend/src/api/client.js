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

// ---- Chat ala WhatsApp (guest <-> host) ----
export const listConversations = () => http.get('/conversations').then(r => r.data.conversations || []);
export const getConversation = (id) => http.get(`/conversations/${id}`).then(r => r.data);
export const createConversation = (bookingId) =>
  http.post('/conversations', { booking_id: bookingId }).then(r => r.data.conversation);
export const sendMessage = (convId, body, clientMessageId) =>
  http.post(`/conversations/${convId}/messages`, {
    message: { body, message_type: 'text', client_message_id: clientMessageId },
  }).then(r => r.data.message);
export const markConversationRead = (id) => http.post(`/conversations/${id}/mark_as_read`).then(r => r.data);
export const toggleWhatsappSync = (id) => http.post(`/conversations/${id}/toggle_whatsapp`).then(r => r.data.conversation);

// Link klik-untuk-chat WhatsApp (dipakai utk buka WA asli dari halaman chat/booking)
export const waLink = (phone, text) => {
  if (!phone) return null;
  let d = String(phone).replace(/\D/g, '');
  if (d.startsWith('0')) d = '62' + d.slice(1);
  return `https://wa.me/${d}` + (text ? `?text=${encodeURIComponent(text)}` : '');
};


// ---- Master Data: floor & unit (grid) + smart lock (7EVEN KEY / TTLOCK) ----
export const getFloorGrid = (hotelId) => http.get(`/master_data/hotels/${hotelId}/grid`).then(r => r.data);
export const createFloor = (hotelId, body) => http.post(`/master_data/hotels/${hotelId}/floors`, body).then(r => r.data.floor);
export const updateFloor = (id, body) => http.patch(`/master_data/floors/${id}`, body).then(r => r.data.floor);
export const deleteFloor = (id) => http.delete(`/master_data/floors/${id}`).then(r => r.data);
export const createRoom = (hotelId, body) => http.post(`/master_data/hotels/${hotelId}/rooms`, body).then(r => r.data.room);
export const getRoom = (id) => http.get(`/master_data/rooms/${id}`).then(r => r.data.room);
export const updateRoom = (id, body) => http.patch(`/master_data/rooms/${id}`, body).then(r => r.data.room);
export const getRoomSmartLock = (roomId) => http.get(`/master_data/rooms/${roomId}/smart_lock`).then(r => r.data.smart_lock);
export const installSmartLock = (roomId, body) => http.post(`/master_data/rooms/${roomId}/smart_lock`, body).then(r => r.data.smart_lock);
export const pairSmartLock = (deviceId) => http.post(`/master_data/smart_locks/${deviceId}/pair`).then(r => r.data);
export const refreshSmartLock = (deviceId) => http.post(`/master_data/smart_locks/${deviceId}/refresh`).then(r => r.data.smart_lock);
export const setMasterPasscode = (deviceId, master_passcode) =>
  http.patch(`/master_data/smart_locks/${deviceId}/master_config`, { master_passcode }).then(r => r.data);
export const addMasterKey = (deviceId, body) => http.post(`/master_data/smart_locks/${deviceId}/master_keys`, body).then(r => r.data.master_key);
export const revokeMasterKey = (deviceId, keyId) => http.delete(`/master_data/smart_locks/${deviceId}/master_keys/${keyId}`).then(r => r.data);
export const generateTempKey = (deviceId, body) => http.post(`/master_data/smart_locks/${deviceId}/temporary_keys`, body).then(r => r.data);
export const revokeTempKey = (deviceId, keyId) => http.delete(`/master_data/smart_locks/${deviceId}/temporary_keys/${keyId}`).then(r => r.data);

export const formatIDR = (n) =>
  new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(n || 0);

export const PERIOD_LABEL = { daily: 'Harian', weekly: 'Mingguan', monthly: 'Bulanan' };
