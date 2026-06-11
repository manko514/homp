'use client';

import { useState, useEffect } from 'react';
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip,
  ResponsiveContainer, PieChart, Pie, Cell, Legend,
} from 'recharts';
import { API_URL } from '@/lib/config';

// ─── Types ────────────────────────────────────────────────────────────────────

interface CohortRow {
  cohortMonth: string;
  cohortSize: number;
  retention: Record<string, number | null>;
}

interface GuestLtv {
  guestId: string;
  name: string;
  email: string;
  total: number;
  hotel: number;
  fnb: number;
  stays: number;
}

interface ChannelRow {
  channel: string;
  bookings: number;
  revenue: number;
  share: number;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

const CHANNEL_COLORS = ['#2196F3', '#4CAF50', '#FF9800', '#E91E63', '#9C27B0', '#00BCD4'];

function retentionColor(pct: number | null): string {
  if (pct === null) return '#f3f4f6';
  if (pct >= 60) return '#4CAF50';
  if (pct >= 30) return '#FF9800';
  return '#F44336';
}

function retentionTextColor(pct: number | null): string {
  return pct === null ? '#d1d5db' : '#fff';
}

const fmt = (n: number) =>
  n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });

// ─── Page ─────────────────────────────────────────────────────────────────────

type Tab = 'cohort' | 'ltv' | 'channel';

export default function AnalyticsPage() {
  const [tab, setTab] = useState<Tab>('cohort');
  const [cohorts, setCohorts] = useState<CohortRow[]>([]);
  const [ltvGuests, setLtvGuests] = useState<GuestLtv[]>([]);
  const [channels, setChannels] = useState<ChannelRow[]>([]);
  const [totalBookings, setTotalBookings] = useState(0);
  const [loading, setLoading] = useState(false);
  const [loaded, setLoaded] = useState<Set<Tab>>(new Set());

  useEffect(() => { fetchTab(tab); }, [tab]);

  async function fetchTab(t: Tab) {
    if (loaded.has(t)) return;
    setLoading(true);
    const token = localStorage.getItem('homp_token');
    const headers = { Authorization: `Bearer ${token}` };
    try {
      if (t === 'cohort') {
        const res = await fetch(`${API_URL}/reports/analytics/cohort`, { headers });
        if (res.ok) { const d = await res.json(); setCohorts(d.cohorts ?? []); }
      } else if (t === 'ltv') {
        const res = await fetch(`${API_URL}/reports/analytics/guest-ltv?limit=20`, { headers });
        if (res.ok) { const d = await res.json(); setLtvGuests(d.guests ?? []); }
      } else if (t === 'channel') {
        const res = await fetch(`${API_URL}/reports/analytics/channel-attribution`, { headers });
        if (res.ok) { const d = await res.json(); setChannels(d.channels ?? []); setTotalBookings(d.totalBookings ?? 0); }
      }
      setLoaded((prev) => new Set([...prev, t]));
    } finally {
      setLoading(false);
    }
  }

  const tabs: { key: Tab; label: string }[] = [
    { key: 'cohort', label: 'Cohort Retention' },
    { key: 'ltv', label: 'Guest Lifetime Value' },
    { key: 'channel', label: 'Channel Attribution' },
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-xl font-bold text-gray-800">Advanced Analytics</h1>
        <p className="text-sm text-gray-500 mt-0.5">Cohort retention · Guest LTV · Channel attribution</p>
      </div>

      {/* Tab bar */}
      <div className="flex gap-2 border-b">
        {tabs.map((t) => (
          <button
            key={t.key}
            onClick={() => setTab(t.key)}
            className="px-4 py-2 text-sm font-medium transition-colors border-b-2"
            style={{
              borderColor: tab === t.key ? '#1E2A3A' : 'transparent',
              color: tab === t.key ? '#1E2A3A' : '#6b7280',
            }}
          >
            {t.label}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="text-center py-20 text-gray-400">Loading analytics…</div>
      ) : (
        <>
          {/* ── Cohort Retention ── */}
          {tab === 'cohort' && (
            <div className="bg-white rounded-xl border shadow overflow-x-auto">
              <div className="px-5 py-4 border-b">
                <h2 className="font-semibold text-gray-700">Guest Cohort Retention</h2>
                <p className="text-xs text-gray-400 mt-0.5">% of guests in each cohort who returned in subsequent months (M0 = acquisition month)</p>
              </div>
              {cohorts.length === 0 ? (
                <p className="text-center text-gray-400 py-10">No reservation data yet</p>
              ) : (
                <table className="text-sm min-w-full">
                  <thead>
                    <tr className="bg-gray-50 text-left">
                      <th className="px-4 py-3 font-medium text-gray-500">Cohort</th>
                      <th className="px-4 py-3 font-medium text-gray-500 text-right">Size</th>
                      {['M0', 'M1', 'M2', 'M3', 'M4', 'M5'].map((m) => (
                        <th key={m} className="px-3 py-3 font-medium text-gray-500 text-center w-14">{m}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody className="divide-y">
                    {cohorts.map((row) => (
                      <tr key={row.cohortMonth}>
                        <td className="px-4 py-2 font-medium text-gray-700">{row.cohortMonth}</td>
                        <td className="px-4 py-2 text-right text-gray-500">{row.cohortSize}</td>
                        {[0, 1, 2, 3, 4, 5].map((i) => {
                          const pct = row.retention[`m${i}`] ?? null;
                          return (
                            <td key={i} className="px-1 py-1 text-center">
                              <div
                                className="mx-auto w-12 h-8 flex items-center justify-center rounded text-xs font-bold"
                                style={{ backgroundColor: retentionColor(pct), color: retentionTextColor(pct) }}
                              >
                                {pct !== null ? `${pct}%` : '–'}
                              </div>
                            </td>
                          );
                        })}
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
              <div className="flex items-center gap-4 px-5 py-3 border-t text-xs text-gray-500">
                <span><span className="inline-block w-3 h-3 rounded mr-1" style={{ backgroundColor: '#4CAF50' }} />≥60%</span>
                <span><span className="inline-block w-3 h-3 rounded mr-1" style={{ backgroundColor: '#FF9800' }} />30–59%</span>
                <span><span className="inline-block w-3 h-3 rounded mr-1" style={{ backgroundColor: '#F44336' }} />&lt;30%</span>
              </div>
            </div>
          )}

          {/* ── Guest LTV ── */}
          {tab === 'ltv' && (
            <div className="space-y-5">
              {/* Bar chart */}
              <div className="bg-white rounded-xl border shadow p-5">
                <h2 className="font-semibold text-gray-700 mb-4">Top 20 Guests by Lifetime Value</h2>
                <ResponsiveContainer width="100%" height={280}>
                  <BarChart data={ltvGuests} layout="vertical" margin={{ left: 120, right: 20 }}>
                    <CartesianGrid strokeDasharray="3 3" horizontal={false} />
                    <XAxis type="number" tickFormatter={(v) => `$${v.toLocaleString()}`} tick={{ fontSize: 11 }} />
                    <YAxis type="category" dataKey="name" tick={{ fontSize: 11 }} width={120} />
                    <Tooltip formatter={(v: any) => [`$${fmt(Number(v))}`, '']} />
                    <Legend />
                    <Bar dataKey="hotel" name="Hotel" stackId="a" fill="#1E2A3A" />
                    <Bar dataKey="fnb" name="F&B" stackId="a" fill="#4CAF50" />
                  </BarChart>
                </ResponsiveContainer>
              </div>

              {/* Table */}
              <div className="bg-white rounded-xl border shadow overflow-hidden">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="bg-gray-50 text-left">
                      <th className="px-4 py-3 font-medium text-gray-500">#</th>
                      <th className="px-4 py-3 font-medium text-gray-500">Guest</th>
                      <th className="px-4 py-3 font-medium text-gray-500 text-right">Stays</th>
                      <th className="px-4 py-3 font-medium text-gray-500 text-right">Hotel</th>
                      <th className="px-4 py-3 font-medium text-gray-500 text-right">F&B</th>
                      <th className="px-4 py-3 font-medium text-gray-500 text-right">Total LTV</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y">
                    {ltvGuests.map((g, i) => (
                      <tr key={g.guestId} className="hover:bg-gray-50">
                        <td className="px-4 py-3 text-gray-400 text-xs">{i + 1}</td>
                        <td className="px-4 py-3">
                          <p className="font-medium text-gray-800">{g.name}</p>
                          <p className="text-xs text-gray-400">{g.email}</p>
                        </td>
                        <td className="px-4 py-3 text-right text-gray-600">{g.stays}</td>
                        <td className="px-4 py-3 text-right text-gray-600">${fmt(g.hotel)}</td>
                        <td className="px-4 py-3 text-right text-gray-600">${fmt(g.fnb)}</td>
                        <td className="px-4 py-3 text-right font-bold text-gray-800">${fmt(g.total)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* ── Channel Attribution ── */}
          {tab === 'channel' && (
            <div className="grid grid-cols-2 gap-5">
              {/* Pie chart */}
              <div className="bg-white rounded-xl border shadow p-5">
                <h2 className="font-semibold text-gray-700 mb-4">Booking Share by Channel</h2>
                {channels.length === 0 ? (
                  <p className="text-center text-gray-400 py-10">No data yet</p>
                ) : (
                  <ResponsiveContainer width="100%" height={260}>
                    <PieChart>
                      <Pie
                        data={channels}
                        dataKey="share"
                        nameKey="channel"
                        cx="50%"
                        cy="50%"
                        outerRadius={100}
                        label={({ channel, share }: any) => `${channel}: ${share}%`}
                      >
                        {channels.map((_, i) => (
                          <Cell key={i} fill={CHANNEL_COLORS[i % CHANNEL_COLORS.length]} />
                        ))}
                      </Pie>
                      <Tooltip formatter={(v: any) => [`${v}%`, 'Share']} />
                    </PieChart>
                  </ResponsiveContainer>
                )}
              </div>

              {/* Channel table */}
              <div className="bg-white rounded-xl border shadow overflow-hidden">
                <div className="px-5 py-4 border-b flex items-center justify-between">
                  <h2 className="font-semibold text-gray-700">Channel Breakdown</h2>
                  <span className="text-xs text-gray-400">{totalBookings} total bookings</span>
                </div>
                <table className="w-full text-sm">
                  <thead>
                    <tr className="bg-gray-50 text-left">
                      <th className="px-4 py-3 font-medium text-gray-500">Channel</th>
                      <th className="px-4 py-3 font-medium text-gray-500 text-right">Bookings</th>
                      <th className="px-4 py-3 font-medium text-gray-500 text-right">Share</th>
                      <th className="px-4 py-3 font-medium text-gray-500 text-right">Revenue</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y">
                    {channels.map((c, i) => (
                      <tr key={c.channel} className="hover:bg-gray-50">
                        <td className="px-4 py-3 flex items-center gap-2">
                          <span
                            className="inline-block w-2.5 h-2.5 rounded-full flex-shrink-0"
                            style={{ backgroundColor: CHANNEL_COLORS[i % CHANNEL_COLORS.length] }}
                          />
                          <span className="font-medium text-gray-700 capitalize">{c.channel}</span>
                        </td>
                        <td className="px-4 py-3 text-right text-gray-600">{c.bookings}</td>
                        <td className="px-4 py-3 text-right">
                          <div className="flex items-center justify-end gap-2">
                            <div className="w-16 h-1.5 bg-gray-100 rounded overflow-hidden">
                              <div
                                className="h-full rounded"
                                style={{ width: `${c.share}%`, backgroundColor: CHANNEL_COLORS[i % CHANNEL_COLORS.length] }}
                              />
                            </div>
                            <span className="text-gray-600 w-8 text-right">{c.share}%</span>
                          </div>
                        </td>
                        <td className="px-4 py-3 text-right text-gray-600">${fmt(c.revenue)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}
