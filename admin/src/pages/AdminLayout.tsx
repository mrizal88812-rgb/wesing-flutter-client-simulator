import { Outlet, Link, useLocation } from 'react-router-dom';
import { LayoutDashboard, Music, Upload, Users, LogOut, Sliders, Radio } from 'lucide-react';
import { cn } from '../lib/utils';

export default function AdminLayout() {
  const location = useLocation();

  const navItems = [
    { name: 'Dashboard', path: '/', icon: LayoutDashboard },
    { name: 'Manage Songs', path: '/songs', icon: Music },
    { name: 'User Posts', path: '/recordings', icon: Radio },
    { name: 'Upload Song', path: '/upload', icon: Upload },
    { name: 'Manage Presets', path: '/presets', icon: Sliders },
  ];

  return (
    <div className="min-h-screen bg-gray-50 text-gray-900 flex font-sans">
      {/* Sidebar */}
      <div className="w-64 bg-white border-r border-gray-200 flex flex-col">
        <div className="h-16 flex items-center px-6 border-b border-gray-200">
          <h1 className="text-xl font-bold text-red-600">AudioVault Admin</h1>
        </div>
        <div className="flex-1 py-4">
          <nav className="space-y-1 px-3">
            {navItems.map(item => {
              const isActive = location.pathname === item.path || (item.path !== '/' && location.pathname.startsWith(item.path));
              return (
                <Link
                  key={item.path}
                  to={item.path}
                  className={cn(
                    "flex items-center px-3 py-2.5 text-sm font-medium rounded-lg transition-colors",
                    isActive
                      ? "bg-red-50 text-red-600"
                      : "text-gray-700 hover:bg-gray-100"
                  )}
                >
                  <item.icon className={cn("w-5 h-5 mr-3", isActive ? "text-red-600" : "text-gray-400")} />
                  {item.name}
                </Link>
              );
            })}
          </nav>
        </div>
        <div className="p-4 border-t border-gray-200">
          <a href="/" className="flex items-center px-3 py-2 text-sm font-medium text-gray-700 rounded-lg hover:bg-gray-100">
            <LogOut className="w-5 h-5 mr-3 text-gray-400" />
            Back to App
          </a>
        </div>
      </div>

      {/* Main Content */}
      <div className="flex-1 overflow-auto bg-gray-50">
        <Outlet />
      </div>
    </div>
  );
}
