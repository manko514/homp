'use client';

import { useEffect } from 'react';
import { useRouter, usePathname } from 'next/navigation';
import { getToken } from '@/lib/api';
import { Sidebar } from '@/components/Sidebar';

const PAGE_TITLES: Record<string, string> = {
  '/dashboard': 'Dashboard',
  '/hotel': 'Hotel',
  '/restaurant': 'Restaurant',
  '/bar': 'Bar',
  '/inventory': 'Inventory',
  '/reports': 'Reports',
  '/payroll': 'Payroll',
  '/inventory-ai': 'Smart Inventory',
  '/anomaly': 'Fraud Alerts',
  '/forecast': 'AI Forecast',
  '/settings': 'Settings',
  '/audit': 'Audit Log',
  '/finance': 'Finance & P&L',
  '/tickets': 'Pool & Tickets',
  '/ai': 'AI Assistant',
  '/attendance': 'Attendance',
  '/push': 'Push Notifications',
};

function Topbar() {
  const pathname = usePathname();
  const router = useRouter();
  const title = PAGE_TITLES[pathname] ?? 'Dashboard';

  return (
    <header
      className="flex items-center justify-between px-6 py-0 flex-shrink-0"
      style={{ height: 56, backgroundColor: '#ffffff', borderBottom: '1px solid #eef0f3' }}
    >
      {/* Left: breadcrumb */}
      <div className="flex items-center gap-2 text-sm">
        <span style={{ color: '#94a3b8' }}>Home</span>
        <span style={{ color: '#cbd5e1' }}>›</span>
        <span className="font-semibold" style={{ color: '#1E2A3A' }}>{title}</span>
      </div>

      {/* Right: search + user */}
      <div className="flex items-center gap-4">
        {/* Search box */}
        <div
          className="flex items-center gap-2 px-3 py-1.5 rounded-md text-sm"
          style={{ backgroundColor: '#F5F6FA', color: '#94a3b8', width: 180 }}
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
          </svg>
          <span>Search…</span>
        </div>

        {/* Notification bell */}
        <button className="relative" style={{ color: '#64748b' }}>
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9" />
            <path d="M13.73 21a2 2 0 0 1-3.46 0" />
          </svg>
          <span
            className="absolute -top-1 -right-1 w-4 h-4 rounded-full text-white flex items-center justify-center"
            style={{ fontSize: 9, backgroundColor: '#F44336' }}
          >3</span>
        </button>

        {/* User avatar */}
        <div className="flex items-center gap-2 cursor-pointer" onClick={() => {}}>
          <div
            className="w-8 h-8 rounded-full flex items-center justify-center text-white text-xs font-bold"
            style={{ backgroundColor: '#2196F3' }}
          >
            A
          </div>
          <div className="hidden sm:block">
            <p className="text-xs font-semibold" style={{ color: '#1E2A3A' }}>Admin</p>
            <p className="text-xs" style={{ color: '#94a3b8' }}>Manager</p>
          </div>
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#94a3b8" strokeWidth="2">
            <polyline points="6 9 12 15 18 9" />
          </svg>
        </div>
      </div>
    </header>
  );
}

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();

  useEffect(() => {
    if (!getToken()) {
      router.replace('/login');
    }
  }, [router]);

  if (typeof window !== 'undefined' && !getToken()) {
    return null;
  }

  return (
    <div className="flex min-h-screen" style={{ backgroundColor: '#F5F6FA' }}>
      <Sidebar />
      <div className="flex flex-col flex-1 min-w-0">
        <Topbar />
        <main className="flex-1 overflow-auto">
          <div className="max-w-6xl mx-auto px-6 py-6">{children}</div>
        </main>
      </div>
    </div>
  );
}
