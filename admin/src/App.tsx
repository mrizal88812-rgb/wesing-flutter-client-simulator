import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import AdminLayout from './pages/AdminLayout';
import AdminDashboard from './pages/AdminDashboard';
import AdminSongs from './pages/AdminSongs';
import AdminRecordings from './pages/AdminRecordings';
import AdminUpload from './pages/AdminUpload';
import AdminPresets from './pages/AdminPresets';

export default function App() {
  const basename = window.location.pathname.startsWith('/admin') ? '/admin' : '/';

  return (
    <BrowserRouter basename={basename}>
      <Routes>
        <Route path="/" element={<AdminLayout />}>
          <Route index element={<AdminDashboard />} />
          <Route path="songs" element={<AdminSongs />} />
          <Route path="recordings" element={<AdminRecordings />} />
          <Route path="upload" element={<AdminUpload />} />
          <Route path="presets" element={<AdminPresets />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}
