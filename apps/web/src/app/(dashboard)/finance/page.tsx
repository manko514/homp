'use client';

import { useState, useEffect, useCallback } from 'react';
import { API_URL } from '@/lib/config';

interface RevenueStream { amount: number; count: number }
interface PL {
  month: string;
  revenue: { hotel: RevenueStream; restaurant: RevenueStream; bar: RevenueStream; tickets: RevenueStream; total: number };
  expenses: { payroll: { amount: number }; total: number };
  grossProfit: number;
  margin: number;
}
interface DayRow { date: string; hotel: number; restaurant: number; bar: number; tickets: number; total: number }
interface Comparison { current: PL; last: PL; revenueChange: number }

const STREAM_COLORS: Record<string, string> = {
  hotel: '#1E2A3A',
  restaurant: '#FF9800',
  bar: '#9C27B0',
  tickets: '#2196F3',
};

const STREAM_LABELS: Record<string, string> = {
  hotel: '🏨 Hotel',
  restaurant: '🍽️ Restaurant',
  bar: '🍹 Bar',
  tickets: '🎫 Tickets',
};

function fmt(n: number) { return `GHS ${n.toFixed(2)}`; }
function pct(part: number, total: number) { return total > 0 ? ((part / total) * 100).toFixed(1) : '0.0'; }

export default function FinancePage() {
  const [month, setMonth] = useState(() => new Date().toISOString().slice(0, 7));
  const [pl, setPl] = useState<PL | null>(null);
  const [trend, setTrend] = useState<DayRow[]>([]);
  const [comparison, setComparison] = useState<Comparison | null>(null);
  const [loading, setLoading] = useState(true);

  const token = typeof window !== 'undefined' ? localStorage.getItem('homp_token') : '';

  const load = useCallback(async () => {
    setLoading(true);
    const h = { Authorization: `Bearer ${token}` };
    const [plRes, trendRes, compRes] = await Promise.all([
      fetch(`${API_URL}/finance/pl?month=${month}`, { headers: h }),
      fetch(`${API_URL}/finance/trend?month=${month}`, { headers: h }),
      fetch(`${API_URL}/finance/comparison`, { headers: h }),
    ]);
    if (plRes.ok) setPl(await plRes.json());
    if (trendRes.ok) setTrend(await trendRes.json());
    if (compRes.ok) setComparison(await compRes.json());
    setLoading(false);
  }, [month, token]);

  useEffect(() => { load(); }, [load]);

  const streams = pl ? ['hotel', 'restaurant', 'bar', 'tickets'] as const : [];
  const maxDay = trend.length > 0 ? Math.max(...trend.map((d) => d.total), 1) : 1;

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-gray-800">Finance & P&L</h1>
          <p className="text-sm text-gray-500 mt-0.5">Monthly profit & loss, revenue breakdown</p>
        </div>
        <input
          type="month"
          value={month}
          onChange={(e) => setMonth(e.target.value)}
          className="border rounded-lg px-3 py-2 text-sm text-gray-700"
        />
      </div>

      {loading ? (
        <p className="text-sm text-gray-400">Loading financial data…</p>
      ) : (
        <>
          {/* P&L Summary cards */}
          {pl && (
            <div className="grid grid-cols-4 gap-4">
              {[
                { label: 'Total Revenue', value: fmt(pl.revenue.total), icon: '💰', color: '#2E7D32', bg: '#E8F5E9' },
                { label: 'Total Expenses', value: fmt(pl.expenses.total), icon: '📤', color: '#C62828', bg: '#FFEBEE' },
                { label: 'Gross Profit', value: fmt(pl.grossProfit), icon: '📈', color: pl.grossProfit >= 0 ? '#1565C0' : '#C62828', bg: pl.grossProfit >= 0 ? '#E3F2FD' : '#FFEBEE' },
                { label: 'Profit Margin', value: `${pl.margin}%`, icon: '🎯', color: '#7B1FA2', bg: '#F3E5F5' },
              ].map((s) => (
                <div key={s.label} className="rounded-xl border shadow-sm p-4" style={{ backgroundColor: s.bg }}>
                  <div className="flex items-center gap-2 mb-2">
                    <span className="text-xl">{s.icon}</span>
                    <p className="text-xs text-gray-500">{s.label}</p>
                  </div>
                  <p className="text-2xl font-bold" style={{ color: s.color }}>{s.value}</p>
                </div>
              ))}
            </div>
          )}

          {/* MoM comparison */}
          {comparison && (
            <div className="bg-white rounded-xl border shadow-sm p-5 flex items-center gap-6">
              <div>
                <p className="text-xs text-gray-500">vs Last Month</p>
                <p className="text-sm font-semibold text-gray-700 mt-0.5">
                  {comparison.last.month}: {fmt(comparison.last.revenue.total)}
                </p>
              </div>
              <div className="w-px h-10 bg-gray-200" />
              <div>
                <p className="text-xs text-gray-500">This Month</p>
                <p className="text-sm font-semibold text-gray-700 mt-0.5">
                  {comparison.current.month}: {fmt(comparison.current.revenue.total)}
                </p>
              </div>
              <div className="w-px h-10 bg-gray-200" />
              <div className="flex items-center gap-2">
                <span className="text-2xl">{comparison.revenueChange >= 0 ? '📈' : '📉'}</span>
                <div>
                  <p className="text-xs text-gray-500">Revenue Change</p>
                  <p className="font-bold text-lg" style={{ color: comparison.revenueChange >= 0 ? '#2E7D32' : '#C62828' }}>
                    {comparison.revenueChange >= 0 ? '+' : ''}{comparison.revenueChange}%
                  </p>
                </div>
              </div>
            </div>
          )}

          {/* Revenue breakdown */}
          {pl && (
            <div className="grid grid-cols-2 gap-4">
              {/* By stream */}
              <div className="bg-white rounded-xl border shadow-sm p-5">
                <h3 className="font-semibold text-gray-700 mb-4">Revenue by Stream</h3>
                <div className="space-y-3">
                  {streams.map((key) => {
                    const stream = pl.revenue[key];
                    const p = pct(stream.amount, pl.revenue.total);
                    return (
                      <div key={key}>
                        <div className="flex justify-between text-sm mb-1">
                          <span className="text-gray-600">{STREAM_LABELS[key]}</span>
                          <span className="font-medium text-gray-800">{fmt(stream.amount)} <span className="text-gray-400 text-xs">({p}%)</span></span>
                        </div>
                        <div className="h-2 rounded-full bg-gray-100 overflow-hidden">
                          <div
                            className="h-full rounded-full transition-all"
                            style={{ width: `${p}%`, backgroundColor: STREAM_COLORS[key] }}
                          />
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>

              {/* Expense breakdown */}
              <div className="bg-white rounded-xl border shadow-sm p-5">
                <h3 className="font-semibold text-gray-700 mb-4">Expense Breakdown</h3>
                <div className="space-y-3">
                  <div className="flex justify-between items-center p-3 rounded-lg" style={{ backgroundColor: '#FFF3E0' }}>
                    <div className="flex items-center gap-2">
                      <span>💼</span>
                      <span className="text-sm text-gray-600">Payroll (Disbursed)</span>
                    </div>
                    <span className="font-bold text-sm" style={{ color: '#E65100' }}>{fmt(pl.expenses.payroll.amount)}</span>
                  </div>
                  <div className="flex justify-between items-center p-3 rounded-lg bg-gray-50">
                    <span className="text-sm font-semibold text-gray-700">Total Expenses</span>
                    <span className="font-bold text-sm text-gray-800">{fmt(pl.expenses.total)}</span>
                  </div>
                  <div className="flex justify-between items-center p-3 rounded-lg" style={{ backgroundColor: pl.grossProfit >= 0 ? '#E8F5E9' : '#FFEBEE' }}>
                    <span className="text-sm font-semibold" style={{ color: pl.grossProfit >= 0 ? '#2E7D32' : '#C62828' }}>Gross Profit</span>
                    <span className="font-bold text-sm" style={{ color: pl.grossProfit >= 0 ? '#2E7D32' : '#C62828' }}>{fmt(pl.grossProfit)}</span>
                  </div>
                </div>

                {/* Counts */}
                <div className="mt-4 grid grid-cols-2 gap-2">
                  {streams.map((key) => (
                    <div key={key} className="text-center p-2 rounded-lg bg-gray-50">
                      <p className="text-xs text-gray-400">{STREAM_LABELS[key]}</p>
                      <p className="font-bold text-gray-700 text-sm">{pl.revenue[key].count} txns</p>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}

          {/* Daily trend table */}
          {trend.length > 0 && (
            <div className="bg-white rounded-xl border shadow-sm overflow-hidden">
              <div className="px-5 py-4 border-b flex items-center justify-between">
                <h3 className="font-semibold text-gray-700">Daily Revenue — {month}</h3>
                <span className="text-xs text-gray-400">{trend.length} days</span>
              </div>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="bg-gray-50 text-left">
                      <th className="px-4 py-3 font-medium text-gray-500">Date</th>
                      <th className="px-4 py-3 font-medium text-gray-500 text-right">Hotel</th>
                      <th className="px-4 py-3 font-medium text-gray-500 text-right">Restaurant</th>
                      <th className="px-4 py-3 font-medium text-gray-500 text-right">Bar</th>
                      <th className="px-4 py-3 font-medium text-gray-500 text-right">Tickets</th>
                      <th className="px-4 py-3 font-medium text-gray-500 text-right">Total</th>
                      <th className="px-4 py-3 font-medium text-gray-500">Trend</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y">
                    {trend.map((d) => (
                      <tr key={d.date} className="hover:bg-gray-50">
                        <td className="px-4 py-2.5 font-medium text-gray-700">
                          {new Date(d.date + 'T12:00:00').toLocaleDateString('en-GB', { weekday: 'short', day: '2-digit', month: 'short' })}
                        </td>
                        <td className="px-4 py-2.5 text-right text-gray-600">{d.hotel > 0 ? fmt(d.hotel) : '—'}</td>
                        <td className="px-4 py-2.5 text-right text-gray-600">{d.restaurant > 0 ? fmt(d.restaurant) : '—'}</td>
                        <td className="px-4 py-2.5 text-right text-gray-600">{d.bar > 0 ? fmt(d.bar) : '—'}</td>
                        <td className="px-4 py-2.5 text-right text-gray-600">{d.tickets > 0 ? fmt(d.tickets) : '—'}</td>
                        <td className="px-4 py-2.5 text-right font-bold text-gray-800">{d.total > 0 ? fmt(d.total) : '—'}</td>
                        <td className="px-4 py-2.5">
                          <div className="h-2 rounded-full bg-gray-100 overflow-hidden w-24">
                            <div
                              className="h-full rounded-full"
                              style={{ width: `${(d.total / maxDay) * 100}%`, backgroundColor: '#1E2A3A' }}
                            />
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                  <tfoot>
                    <tr className="bg-gray-50 border-t-2 border-gray-200">
                      <td className="px-4 py-3 font-bold text-gray-700">Month Total</td>
                      <td className="px-4 py-3 text-right font-bold">{pl ? fmt(pl.revenue.hotel.amount) : '—'}</td>
                      <td className="px-4 py-3 text-right font-bold">{pl ? fmt(pl.revenue.restaurant.amount) : '—'}</td>
                      <td className="px-4 py-3 text-right font-bold">{pl ? fmt(pl.revenue.bar.amount) : '—'}</td>
                      <td className="px-4 py-3 text-right font-bold">{pl ? fmt(pl.revenue.tickets.amount) : '—'}</td>
                      <td className="px-4 py-3 text-right font-bold text-green-700">{pl ? fmt(pl.revenue.total) : '—'}</td>
                      <td />
                    </tr>
                  </tfoot>
                </table>
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}
