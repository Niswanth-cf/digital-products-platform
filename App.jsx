import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import { Toaster } from 'react-hot-toast';
import Navbar from './components/layout/Navbar';
import Footer from './components/layout/Footer';
import { ProtectedRoute, AdminRoute, GuestRoute } from './components/ProtectedRoute';
import Home from './pages/Home';
import { Login, Register } from './pages/Auth';
import Products from './pages/Products';
import ProductDetail from './pages/ProductDetail';
import Pricing from './pages/Pricing';
import Dashboard from './pages/Dashboard';
import AdminPanel from './pages/AdminPanel';
import './index.css';

function App() {
  return (
    <AuthProvider>
      <Router>
        <div className="app">
          <Toaster
            position="top-right"
            toastOptions={{
              duration: 3000,
              style: {
                background: '#1a1a2e',
                color: '#e0e0ff',
                border: '1px solid rgba(108, 99, 255, 0.3)',
                borderRadius: '12px',
                fontSize: '0.9rem'
              }
            }}
          />
          <Navbar />
          <main className="main-content">
            <Routes>
              <Route path="/" element={<Home />} />
              <Route path="/login" element={<GuestRoute><Login /></GuestRoute>} />
              <Route path="/register" element={<GuestRoute><Register /></GuestRoute>} />
              <Route path="/products" element={<Products />} />
              <Route path="/products/:id" element={<ProductDetail />} />
              <Route path="/pricing" element={<Pricing />} />
              <Route path="/dashboard" element={<ProtectedRoute><Dashboard /></ProtectedRoute>} />
              <Route path="/dashboard/downloads" element={<ProtectedRoute><Dashboard /></ProtectedRoute>} />
              <Route path="/dashboard/settings" element={<ProtectedRoute><Dashboard /></ProtectedRoute>} />
              <Route path="/admin" element={<AdminRoute><AdminPanel /></AdminRoute>} />
            </Routes>
          </main>
          <Footer />
        </div>
      </Router>
    </AuthProvider>
  );
}

export default App;
