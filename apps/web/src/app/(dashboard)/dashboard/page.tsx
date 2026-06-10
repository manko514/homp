'use client';

import { useState, useEffect, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { API_URL } from '@/lib/config';
import { getToken, clearToken } from '@/lib/api';

interface ExecSummary {
  hotel: { total: number; occupied: number; available: number; occupancy: number };
  revenue: { today: number; thisMonth: number };
  restaurant: { ordersToday: number; revenueToday: number };
  bar: { salesToday: number; revenueToday: number };
  tickets: { activeNow: number; soldToday: number; revenueToday: number };
  hr: { totalEmployees: number; pendingPayroll: number };
  alerts: { anomalies: number; lowStock: number };
  ai: { lastForecast: { forecastDate: string; confidence: number; forecastType: string } | null };
  recentActivity: { eventType: string; resourceType: string; actor: string | null; createdAt: string }[];
}

interface DayRevenue { date: string; totalRevenue: number; hotel: { revenue: number }; restaurant: { revenue: number }; bar: { revenue: number } }

function fmt(n: number) { return `GHS ${n.toFixed(2)}`; }
function timeAgo(date: string) {
  const diff = Date.now() - new Date(date).getTime();
  const m = Math.floor(diff / 60000);
  if (m < 1) return 'just now';
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  return new Date(date).toLocaleDateString('en-GB', { day: '2-digit', month: 'short' });
}

const EVENT_COLOR: Record<string, string> = {
  CREATE: '#4CAF50', UPDATE: '#2196F3', DELETE: '#F44336',
  APPROVE: '#9C27B0', DISBURSE: '#00695C', VALIDATE: '#FF9800', LOGIN: '#64748b',
};

export default function DashboardPage() {
  const router = useRouter();
  const [summary, setSummary] = useState<ExecSummary | null>(null);
  const [weekly, setWeekly] = useState<DayRevenue[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const today = new Date().toISOString().split('T')[0];

  const load = useCallback(async () => {
    const token = getToken();
    if (!token) { router.replace('/login'); return; }
    setLoading(true);
    const h = { Authorization: `Bearer ${token}` };
    try {
      const [sRes, wRes] = await Promise.all([
        fetch(`${API_URL}/reports/executive-summary`, { headers: h }),
        fetch(`${API_URL}/reports/weekly-revenue?days=7`, { headers: h }),
      ]);
      if (sRes.status === 401) { clearToken(); router.replace('/login'); return; }
      if (sRes.ok) setSummary(await sRes.json());
      else setError(`API error ${sRes.status} — check API terminal`);
      if (wRes.ok) setWeekly(await wRes.json());
    } catch (e) {
      setError('Cannot reach API — is it running on port 3001?');
    }
    setLoading(false);
  }, [router, today]);

  useEffect(() => { load(); }, [load]);

  const maxRev = weekly.length > 0 ? Math.max(...weekly.map((d) => d.totalRevenue), 1) : 1;

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-center text-gray-400">
          <div className="text-4xl mb-2">⏳</div>
          <p className="text-sm">Loading executive summary…</p>
        </div>
      </div>
    );
  }

  if (error || !summary) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-center">
          <div className="text-4xl mb-3">⚠️</div>
          <p className="text-sm text-red-600 font-medium">{error || 'Failed to load dashboard'}</p>
          <div className="mt-4 space-y-2">
            <p className="text-xs text-gray-400">1. Make sure the API terminal shows &quot;Application is running&quot;</p>
            <p className="text-xs text-gray-400">2. Re-login at <a href="/login" className="text-blue-500 underline">/login</a></p>
          </div>
          <button onClick={load} className="mt-4 px-4 py-2 rounded-lg text-sm text-white" style={{ backgroundColor: '#1E2A3A' }}>
            🔄 Retry
          </button>
        </div>
      </div>
    );
  }

  const kpis = [
    { icon: '🏨', label: 'Occupancy', value: `${summary.hotel.occupancy}%`, sub: `${summary.hotel.occupied}/${summary.hotel.total} rooms`, color: '#1E2A3A', bg: '#E8EDF3' },
    { icon: '💰', label: "Today's Revenue", value: fmt(summary.revenue.today), sub: 'All streams combined', color: '#2E7D32', bg: '#E8F5E9' },
    { icon: '📅', label: 'Month Revenue', value: fmt(summary.revenue.thisMonth), sub: new Date().toLocaleString('default', { month: 'long', year: 'numeric' }), color: '#1565C0', bg: '#E3F2FD' },
    { icon: '👥', label: 'Employees', value: summary.hr.totalEmployees, sub: summary.hr.pendingPayroll > 0 ? `⚠ ${summary.hr.pendingPayroll} payroll pending` : 'All payrolls clear', color: '#7B1FA2', bg: '#F3E5F5' },
    { icon: '🎫', label: 'Active Tickets', value: summary.tickets.activeNow, sub: `${summary.tickets.soldToday} sold today`, color: '#E65100', bg: '#FFF3E0' },
    { icon: '⚠️', label: 'Open Alerts', value: summary.alerts.anomalies + summary.alerts.lowStock, sub: `${summary.alerts.anomalies} anomaly · ${summary.alerts.lowStock} stock`, color: summary.alerts.anomalies + summary.alerts.lowStock > 0 ? '#C62828' : '#2E7D32', bg: summary.alerts.anomalies + summary.alerts.lowStock > 0 ? '#FFEBEE' : '#E8F5E9' },
  ];

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-gray-800">Executive Dashboard</h1>
          <p className="text-sm text-gray-500 mt-0.5">
            {new Date().toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}
          </p>
        </div>
        <button onClick={load} className="text-xs px-3 py-1.5 border rounded-lg text-gray-500 hover:bg-gray-50">
          🔄 Refresh
        </button>
      </div>

      {/* KPI row */}
      <div className="grid grid-cols-3 lg:grid-cols-6 gap-3">
        {kpis.map((k) => (
          <div key={k.label} className="rounded-xl border shadow-sm p-4" style={{ backgroundColor: k.bg }}>
            <div className="flex items-center gap-1.5 mb-2">
              <span className="text-lg">{k.icon}</span>
              <p className="text-xs text-gray-500 leading-tight">{k.label}</p>
            </div>
            <p className="text-xl font-bold leading-tight" style={{ color: k.color }}>{k.value}</p>
            <p className="text-xs text-gray-400 mt-0.5 leading-tight">{k.sub}</p>
          </div>
        ))}
      </div>

      {/* Revenue streams + weekly trend */}
      <div className="grid grid-cols-3 gap-4">
        {/* Stream breakdown */}
        <div className="bg-white rounded-xl border shadow-sm p-5">
          <h3 className="font-semibold text-gray-700 mb-4 text-sm">Today by Stream</h3>
          <div className="space-y-3">
            {[
              { label: '🏨 Hotel', value: summary.revenue.today - summary.restaurant.revenueToday - summary.bar.revenueToday - summary.tickets.revenueToday, color: '#1E2A3A' },
              { label: '🍽️ Restaurant', value: summary.restaurant.revenueToday, color: '#FF9800' },
              { label: '🍹 Bar', value: summary.bar.revenueToday, color: '#9C27B0' },
              { label: '🎫 Tickets', value: summary.tickets.revenueToday, color: '#2196F3' },
            ].map((s) => {
              const total = summary.revenue.today || 1;
              const pct = Math.max(0, Math.round((s.value / total) * 100));
              return (
                <div key={s.label}>
                  <div className="flex justify-between text-xs mb-1">
                    <span className="text-gray-600">{s.label}</span>
                    <span className="font-medium text-gray-800">{fmt(Math.max(0, s.value))}</span>
                  </div>
                  <div className="h-1.5 rounded-full bg-gray-100 overflow-hidden">
                    <div className="h-full rounded-full" style={{ width: `${pct}%`, backgroundColor: s.color }} />
                  </div>
                </div>
              );
            })}
            <div className="pt-3 border-t mt-1 flex justify-between">
              <span className="text-xs font-semibold text-gray-600">Total Today</span>
              <span className="text-sm font-bold" style={{ color: '#1E2A3A' }}>{fmt(summary.revenue.today)}</span>
            </div>
          </div>
        </div>

        {/* Weekly trend bars */}
        <div className="col-span-2 bg-white rounded-xl border shadow-sm p-5">
          <h3 className="font-semibold text-gray-700 mb-4 text-sm">7-Day Revenue Trend</h3>
          {weekly.length === 0 ? (
            <p className="text-sm text-gray-400">No data</p>
          ) : (
            <div className="flex items-end gap-2 h-36">
              {weekly.map((d) => {
                const h = Math.max(4, Math.round((d.totalRevenue / maxRev) * 140));
                const isToday = d.date === new Date().toISOString().slice(0, 10);
                return (
                  <div key={d.date} className="flex-1 flex flex-col items-center gap-1">
                    <span className="text-xs text-gray-400" style={{ fontSize: 9 }}>
                      {d.totalRevenue > 0 ? `${d.totalRevenue.toFixed(0)}` : ''}
                    </span>
                    <div
                      className="w-full rounded-t-md transition-all"
                      style={{ height: h, backgroundColor: isToday ? '#1E2A3A' : '#CBD5E1' }}
                      title={`${d.date}: ${fmt(d.totalRevenue)}`}
                    />
                    <span className="text-xs text-gray-400" style={{ fontSize: 9 }}>
                      {new Date(d.date + 'T12:00:00').toLocaleDateString('en-US', { weekday: 'short' })}
                    </span>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>

      {/* Module stats row */}
      <div className="grid grid-cols-4 gap-4">
        {/* Hotel */}
        <div className="bg-white rounded-xl border shadow-sm p-4">
          <div className="flex items-center gap-2 mb-3">
            <span className="text-xl">🏨</span>
            <h3 className="font-semibold text-gray-700 text-sm">Hotel</h3>
          </div>
          <div className="space-y-2">
            <div className="flex justify-between text-xs">
              <span className="text-gray-500">Occupied</span>
              <span className="font-bold" style={{ color: '#1E2A3A' }}>{summary.hotel.occupied}</span>
            </div>
            <div className="h-2 rounded-full bg-gray-100 overflow-hidden">
              <div className="h-full rounded-full" style={{ width: `${summary.hotel.occupancy}%`, backgroundColor: '#1E2A3A' }} />
            </div>
            <div className="flex justify-between text-xs">
              <span className="text-gray-500">Available</span>
              <span className="font-medium text-green-600">{summary.hotel.available}</span>
            </div>
            <div className="flex justify-between text-xs">
              <span className="text-gray-500">Occupancy</span>
              <span className="font-bold text-gray-800">{summary.hotel.occupancy}%</span>
            </div>
          </div>
        </div>

        {/* Restaurant */}
        <div className="bg-white rounded-xl border shadow-sm p-4">
          <div className="flex items-center gap-2 mb-3">
            <span className="text-xl">🍽️</span>
            <h3 className="font-semibold text-gray-700 text-sm">Restaurant</h3>
          </div>
          <div className="space-y-2 text-xs">
            <div className="flex justify-between">
              <span className="text-gray-500">Orders Today</span>
              <span className="font-bold text-gray-800">{summary.restaurant.ordersToday}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-500">Revenue Today</span>
              <span className="font-bold" style={{ color: '#FF9800' }}>{fmt(summary.restaurant.revenueToday)}</span>
            </div>
          </div>
        </div>

        {/* Bar */}
        <div className="bg-white rounded-xl border shadow-sm p-4">
          <div className="flex items-center gap-2 mb-3">
            <span className="text-xl">🍹</span>
            <h3 className="font-semibold text-gray-700 text-sm">Bar</h3>
          </div>
          <div className="space-y-2 text-xs">
            <div className="flex justify-between">
              <span className="text-gray-500">Sales Today</span>
              <span className="font-bold text-gray-800">{summary.bar.salesToday}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-500">Revenue Today</span>
              <span className="font-bold" style={{ color: '#9C27B0' }}>{fmt(summary.bar.revenueToday)}</span>
            </div>
          </div>
        </div>

        {/* AI Forecast */}
        <div className="bg-white rounded-xl border shadow-sm p-4">
          <div className="flex items-center gap-2 mb-3">
            <span className="text-xl">🤖</span>
            <h3 className="font-semibold text-gray-700 text-sm">AI Forecast</h3>
          </div>
          {summary.ai.lastForecast ? (
            <div className="space-y-2 text-xs">
              <div className="flex justify-between">
                <span className="text-gray-500">Type</span>
                <span className="font-medium text-gray-700">{summary.ai.lastForecast.forecastType}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-500">Confidence</span>
                <span className="font-bold" style={{ color: '#2196F3' }}>{Math.round(Number(summary.ai.lastForecast.confidence) * 100)}%</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-500">Generated</span>
                <span className="text-gray-400">{timeAgo(summary.ai.lastForecast.forecastDate)}</span>
              </div>
            </div>
          ) : (
            <p className="text-xs text-gray-400">No forecast yet — run one in AI Forecast</p>
          )}
        </div>
      </div>

      {/* Recent activity + alerts */}
      <div className="grid grid-cols-2 gap-4">
        {/* Recent audit activity */}
        <div className="bg-white rounded-xl border shadow-sm overflow-hidden">
          <div className="px-5 py-4 border-b flex items-center justify-between">
            <h3 className="font-semibold text-gray-700 text-sm">Recent Activity</h3>
            <a href="/audit" className="text-xs text-blue-500 hover:underline">View all →</a>
          </div>
          {summary.recentActivity.length === 0 ? (
            <p className="text-xs text-gray-400 p-5">No activity logged yet</p>
          ) : (
            <div className="divide-y">
              {summary.recentActivity.map((a, i) => (
                <div key={i} className="px-5 py-3 flex items-center gap-3">
                  <span
                    className="w-2 h-2 rounded-full flex-shrink-0"
                    style={{ backgroundColor: EVENT_COLOR[a.eventType] ?? '#64748b' }}
                  />
                  <div className="flex-1 min-w-0">
                    <p className="text-xs font-medium text-gray-700">
                      <span style={{ color: EVENT_COLOR[a.eventType] }}>{a.eventType}</span>
                      {' '}<span className="font-mono text-gray-500">{a.resourceType}</span>
                    </p>
                    <p className="text-xs text-gray-400">{a.actor ?? 'System'}</p>
                  </div>
                  <span className="text-xs text-gray-400 flex-shrink-0">{timeAgo(a.createdAt)}</span>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Alert summary */}
        <div className="bg-white rounded-xl border shadow-sm overflow-hidden">
          <div className="px-5 py-4 border-b">
            <h3 className="font-semibold text-gray-700 text-sm">System Status</h3>
          </div>
          <div className="p-5 space-y-3">
            {[
              { label: 'Hotel Rooms', status: `${summary.hotel.available} available`, ok: summary.hotel.available > 0, icon: '🏨' },
              { label: 'Inventory Alerts', status: summary.alerts.lowStock > 0 ? `${summary.alerts.lowStock} items low` : 'All stocked', ok: summary.alerts.lowStock === 0, icon: '📦' },
              { label: 'Fraud Alerts', status: summary.alerts.anomalies > 0 ? `${summary.alerts.anomalies} open` : 'No anomalies', ok: summary.alerts.anomalies === 0, icon: '🔍' },
              { label: 'Payroll', status: summary.hr.pendingPayroll > 0 ? `${summary.hr.pendingPayroll} run(s) pending` : 'Up to date', ok: summary.hr.pendingPayroll === 0, icon: '💼' },
              { label: 'Active Tickets', status: `${summary.tickets.activeNow} passes valid`, ok: true, icon: '🎫' },
              { label: 'AI Forecast', status: summary.ai.lastForecast ? `Confidence ${Math.round(Number(summary.ai.lastForecast.confidence) * 100)}%` : 'Not run yet', ok: !!summary.ai.lastForecast, icon: '🤖' },
            ].map((item) => (
              <div key={item.label} className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <span className="text-sm">{item.icon}</span>
                  <span className="text-xs text-gray-600">{item.label}</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-xs text-gray-500">{item.status}</span>
                  <span className="w-2 h-2 rounded-full" style={{ backgroundColor: item.ok ? '#4CAF50' : '#F44336' }} />
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
