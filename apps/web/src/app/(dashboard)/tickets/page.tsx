'use client';

import { useState, useEffect, useCallback } from 'react';
import { API_URL } from '@/lib/config';

interface Ticket {
  id: string;
  guestName: string | null;
  ticketType: string;
  qrToken: string;
  validFrom: string;
  validUntil: string;
  usedAt: string | null;
  status: 'ACTIVE' | 'USED' | 'EXPIRED' | 'CANCELLED';
  purchasePrice: number;
  createdAt: string;
}

interface Stats {
  total: number;
  active: number;
  usedToday: number;
  revenue: number;
  revenueToday: number;
  byType: { type: string; count: number; revenue: number }[];
  defaultPrices: Record<string, number>;
}

const TICKET_TYPES = ['DAY_PASS', 'POOL_ONLY', 'GYM', 'EVENT', 'VIP'];
const TYPE_ICONS: Record<string, string> = {
  DAY_PASS: '🎫',
  POOL_ONLY: '🏊',
  GYM: '💪',
  EVENT: '🎉',
  VIP: '⭐',
};

const STATUS_STYLE: Record<string, { bg: string; text: string }> = {
  ACTIVE:    { bg: '#E8F5E9', text: '#2E7D32' },
  USED:      { bg: '#E3F2FD', text: '#1565C0' },
  EXPIRED:   { bg: '#FFF3E0', text: '#E65100' },
  CANCELLED: { bg: '#FFEBEE', text: '#C62828' },
};

function fmt(date: string) {
  return new Date(date).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
}

export default function TicketsPage() {
  const [tickets, setTickets] = useState<Ticket[]>([]);
  const [stats, setStats] = useState<Stats | null>(null);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState('ALL');
  const [showIssue, setShowIssue] = useState(false);
  const [showValidate, setShowValidate] = useState(false);
  const [validateToken, setValidateToken] = useState('');
  const [validateResult, setValidateResult] = useState<{ valid: boolean; reason: string } | null>(null);
  const [validating, setValidating] = useState(false);
  const [issuing, setIssuing] = useState(false);
  const [error, setError] = useState('');

  // form state
  const [form, setForm] = useState({
    guestName: '',
    ticketType: 'DAY_PASS',
    validFrom: new Date().toISOString().slice(0, 16),
    validUntil: new Date(Date.now() + 86400000).toISOString().slice(0, 16),
    purchasePrice: '50',
  });

  const token = typeof window !== 'undefined' ? localStorage.getItem('homp_token') : '';

  const load = useCallback(async () => {
    setLoading(true);
    const statusFilter = tab === 'ALL' ? '' : `?status=${tab}`;
    const [tRes, sRes] = await Promise.all([
      fetch(`${API_URL}/tickets${statusFilter}`, { headers: { Authorization: `Bearer ${token}` } }),
      fetch(`${API_URL}/tickets/stats`, { headers: { Authorization: `Bearer ${token}` } }),
    ]);
    if (tRes.ok) setTickets(await tRes.json());
    if (sRes.ok) setStats(await sRes.json());
    setLoading(false);
  }, [tab, token]);

  useEffect(() => { load(); }, [load]);

  // Auto-fill price when type changes
  function handleTypeChange(type: string) {
    const price = stats?.defaultPrices[type] ?? 50;
    setForm((f) => ({ ...f, ticketType: type, purchasePrice: String(price) }));
  }

  async function issueTicket() {
    setIssuing(true); setError('');
    const res = await fetch(`${API_URL}/tickets`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        guestName: form.guestName || undefined,
        ticketType: form.ticketType,
        validFrom: new Date(form.validFrom).toISOString(),
        validUntil: new Date(form.validUntil).toISOString(),
        purchasePrice: Number(form.purchasePrice),
      }),
    });
    if (res.ok) {
      setShowIssue(false);
      await load();
    } else {
      const e = await res.json();
      setError(e.message ?? 'Failed to issue ticket');
    }
    setIssuing(false);
  }

  async function validateQR() {
    if (!validateToken.trim()) return;
    setValidating(true); setValidateResult(null);
    const res = await fetch(`${API_URL}/tickets/validate`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ qrToken: validateToken.trim() }),
    });
    if (res.ok) {
      const data = await res.json();
      setValidateResult(data);
      await load();
    }
    setValidating(false);
  }

  async function cancelTicket(id: string) {
    await fetch(`${API_URL}/tickets/${id}/cancel`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${token}` },
    });
    await load();
  }

  const statCards = stats
    ? [
        { label: 'Total Issued', value: stats.total, icon: '🎫', color: '#1E2A3A' },
        { label: 'Active Now', value: stats.active, icon: '✅', color: '#2E7D32' },
        { label: 'Used Today', value: stats.usedToday, icon: '🚪', color: '#1565C0' },
        { label: "Today's Revenue", value: `GHS ${stats.revenueToday.toFixed(2)}`, icon: '💰', color: '#C62828' },
      ]
    : [];

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-gray-800">Pool & Ticketing</h1>
          <p className="text-sm text-gray-500 mt-0.5">Issue passes, validate QR codes at gate</p>
        </div>
        <div className="flex gap-2">
          <button
            onClick={() => { setShowValidate(true); setValidateResult(null); setValidateToken(''); }}
            className="px-4 py-2 rounded-lg border text-sm font-medium text-gray-600 hover:bg-gray-50"
          >
            🔍 Scan QR
          </button>
          <button
            onClick={() => setShowIssue(true)}
            className="px-4 py-2 rounded-lg text-sm font-medium text-white"
            style={{ backgroundColor: '#1E2A3A' }}
          >
            + Issue Ticket
          </button>
        </div>
      </div>

      {/* Stat cards */}
      <div className="grid grid-cols-4 gap-4">
        {statCards.map((s) => (
          <div key={s.label} className="bg-white rounded-xl border shadow-sm p-4">
            <div className="flex items-center gap-2 mb-2">
              <span className="text-xl">{s.icon}</span>
              <p className="text-xs text-gray-500">{s.label}</p>
            </div>
            <p className="text-2xl font-bold" style={{ color: s.color }}>{s.value}</p>
          </div>
        ))}
      </div>

      {/* By-type breakdown */}
      {stats?.byType && stats.byType.length > 0 && (
        <div className="bg-white rounded-xl border shadow-sm p-5">
          <h3 className="font-semibold text-gray-700 mb-3">Revenue by Type</h3>
          <div className="flex gap-4 flex-wrap">
            {stats.byType.map((b) => (
              <div key={b.type} className="flex items-center gap-2 bg-gray-50 px-3 py-2 rounded-lg">
                <span>{TYPE_ICONS[b.type] ?? '🎫'}</span>
                <div>
                  <p className="text-xs text-gray-500">{b.type.replace('_', ' ')}</p>
                  <p className="text-sm font-bold text-gray-800">{b.count} sold · GHS {b.revenue.toFixed(2)}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Tabs + table */}
      <div className="bg-white rounded-xl border shadow-sm overflow-hidden">
        <div className="flex border-b px-5 pt-4 gap-1">
          {['ALL', 'ACTIVE', 'USED', 'EXPIRED', 'CANCELLED'].map((t) => (
            <button
              key={t}
              onClick={() => setTab(t)}
              className="px-3 py-2 text-xs font-medium rounded-t-lg transition-colors"
              style={{
                color: tab === t ? '#1E2A3A' : '#64748b',
                borderBottom: tab === t ? '2px solid #1E2A3A' : '2px solid transparent',
              }}
            >
              {t.replace('_', ' ')}
            </button>
          ))}
        </div>

        {loading ? (
          <p className="text-sm text-gray-400 p-6">Loading…</p>
        ) : tickets.length === 0 ? (
          <div className="p-10 text-center text-gray-400">
            <div className="text-4xl mb-2">🎫</div>
            <p>No tickets found</p>
          </div>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-gray-50 text-left">
                <th className="px-4 py-3 font-medium text-gray-500">Guest</th>
                <th className="px-4 py-3 font-medium text-gray-500">Type</th>
                <th className="px-4 py-3 font-medium text-gray-500">QR Token</th>
                <th className="px-4 py-3 font-medium text-gray-500">Valid</th>
                <th className="px-4 py-3 font-medium text-gray-500 text-right">Price</th>
                <th className="px-4 py-3 font-medium text-gray-500">Status</th>
                <th className="px-4 py-3 font-medium text-gray-500">Used At</th>
                <th className="px-4 py-3 font-medium text-gray-500"></th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {tickets.map((t) => {
                const ss = STATUS_STYLE[t.status] ?? STATUS_STYLE.EXPIRED;
                return (
                  <tr key={t.id} className="hover:bg-gray-50">
                    <td className="px-4 py-3 font-medium text-gray-800">{t.guestName ?? 'Walk-in'}</td>
                    <td className="px-4 py-3">
                      <span className="flex items-center gap-1">
                        {TYPE_ICONS[t.ticketType] ?? '🎫'}
                        <span className="text-gray-600">{t.ticketType.replace('_', ' ')}</span>
                      </span>
                    </td>
                    <td className="px-4 py-3 font-mono text-xs text-gray-500">{t.qrToken}</td>
                    <td className="px-4 py-3 text-xs text-gray-500">
                      {fmt(t.validFrom)} – {fmt(t.validUntil)}
                    </td>
                    <td className="px-4 py-3 text-right font-medium">GHS {Number(t.purchasePrice).toFixed(2)}</td>
                    <td className="px-4 py-3">
                      <span className="px-2 py-0.5 rounded-full text-xs font-medium"
                        style={{ backgroundColor: ss.bg, color: ss.text }}>
                        {t.status}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-xs text-gray-400">
                      {t.usedAt ? new Date(t.usedAt).toLocaleTimeString() : '—'}
                    </td>
                    <td className="px-4 py-3">
                      {t.status === 'ACTIVE' && (
                        <button
                          onClick={() => cancelTicket(t.id)}
                          className="text-xs text-red-500 hover:underline"
                        >
                          Cancel
                        </button>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>

      {/* Issue Ticket Modal */}
      {showIssue && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50">
          <div className="bg-white rounded-2xl shadow-xl w-full max-w-md p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="font-bold text-gray-800">Issue New Ticket</h2>
              <button onClick={() => setShowIssue(false)} className="text-gray-400 hover:text-gray-600">✕</button>
            </div>
            {error && <p className="text-xs text-red-600 bg-red-50 rounded-lg px-3 py-2 mb-3">{error}</p>}
            <div className="space-y-3">
              <div>
                <label className="text-xs text-gray-500">Guest Name (optional)</label>
                <input
                  value={form.guestName}
                  onChange={(e) => setForm((f) => ({ ...f, guestName: e.target.value }))}
                  placeholder="Walk-in guest"
                  className="w-full mt-1 border rounded-lg px-3 py-2 text-sm"
                />
              </div>
              <div>
                <label className="text-xs text-gray-500">Ticket Type</label>
                <select
                  value={form.ticketType}
                  onChange={(e) => handleTypeChange(e.target.value)}
                  className="w-full mt-1 border rounded-lg px-3 py-2 text-sm"
                >
                  {TICKET_TYPES.map((t) => (
                    <option key={t} value={t}>{TYPE_ICONS[t]} {t.replace('_', ' ')}</option>
                  ))}
                </select>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs text-gray-500">Valid From</label>
                  <input
                    type="datetime-local"
                    value={form.validFrom}
                    onChange={(e) => setForm((f) => ({ ...f, validFrom: e.target.value }))}
                    className="w-full mt-1 border rounded-lg px-3 py-2 text-sm"
                  />
                </div>
                <div>
                  <label className="text-xs text-gray-500">Valid Until</label>
                  <input
                    type="datetime-local"
                    value={form.validUntil}
                    onChange={(e) => setForm((f) => ({ ...f, validUntil: e.target.value }))}
                    className="w-full mt-1 border rounded-lg px-3 py-2 text-sm"
                  />
                </div>
              </div>
              <div>
                <label className="text-xs text-gray-500">Price (GHS)</label>
                <input
                  type="number"
                  value={form.purchasePrice}
                  onChange={(e) => setForm((f) => ({ ...f, purchasePrice: e.target.value }))}
                  className="w-full mt-1 border rounded-lg px-3 py-2 text-sm"
                />
              </div>
            </div>
            <div className="flex gap-2 mt-5">
              <button
                onClick={issueTicket}
                disabled={issuing}
                className="flex-1 py-2.5 rounded-lg text-white font-medium text-sm disabled:opacity-60"
                style={{ backgroundColor: '#1E2A3A' }}
              >
                {issuing ? 'Issuing…' : '🎫 Issue Ticket'}
              </button>
              <button
                onClick={() => setShowIssue(false)}
                className="px-4 py-2.5 rounded-lg border text-sm text-gray-500"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Validate QR Modal */}
      {showValidate && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50">
          <div className="bg-white rounded-2xl shadow-xl w-full max-w-sm p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="font-bold text-gray-800">Gate QR Validation</h2>
              <button onClick={() => setShowValidate(false)} className="text-gray-400 hover:text-gray-600">✕</button>
            </div>
            <div className="space-y-3">
              <div>
                <label className="text-xs text-gray-500">Enter or scan QR token</label>
                <input
                  value={validateToken}
                  onChange={(e) => setValidateToken(e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && validateQR()}
                  placeholder="HOMP-XXXXXXXXXXXXXXXX"
                  className="w-full mt-1 border rounded-lg px-3 py-2 text-sm font-mono"
                  autoFocus
                />
              </div>
              <button
                onClick={validateQR}
                disabled={validating || !validateToken}
                className="w-full py-2.5 rounded-lg text-white font-medium text-sm disabled:opacity-60"
                style={{ backgroundColor: '#1565C0' }}
              >
                {validating ? 'Checking…' : '🔍 Validate'}
              </button>

              {validateResult && (
                <div
                  className="rounded-xl p-4 text-center mt-3"
                  style={{
                    backgroundColor: validateResult.valid ? '#E8F5E9' : '#FFEBEE',
                    border: `1px solid ${validateResult.valid ? '#A5D6A7' : '#EF9A9A'}`,
                  }}
                >
                  <div className="text-4xl mb-2">{validateResult.valid ? '✅' : '❌'}</div>
                  <p className="font-bold text-sm" style={{ color: validateResult.valid ? '#2E7D32' : '#C62828' }}>
                    {validateResult.valid ? 'ENTRY GRANTED' : 'ACCESS DENIED'}
                  </p>
                  <p className="text-xs mt-1 text-gray-600">{validateResult.reason}</p>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
