'use client';

import { useState, useEffect } from 'react';
import { API_URL } from '@/lib/config';

interface PurchaseOrder {
  id: string;
  itemName: string;
  currentQty: number;
  reorderQty: number;
  unit: string;
  reason: string;
  status: 'PENDING' | 'APPROVED' | 'DISMISSED';
  aiGenerated: boolean;
  createdAt: string;
}

interface StockAlert {
  id: string;
  name: string;
  category: string;
  unit: string;
  currentQty: number;
  reorderLevel: number;
}

interface AlertSummary {
  total: number;
  belowReorderCount: number;
  belowReorder: StockAlert[];
}

const STATUS_STYLE: Record<string, { bg: string; text: string; label: string }> = {
  PENDING:   { bg: '#FFF8E1', text: '#F9A825', label: '⏳ Pending' },
  APPROVED:  { bg: '#F1F8E9', text: '#33691E', label: '✅ Approved' },
  DISMISSED: { bg: '#FAFAFA', text: '#9E9E9E', label: '✕ Dismissed' },
};

export default function InventoryAiPage() {
  const [orders, setOrders] = useState<PurchaseOrder[]>([]);
  const [alerts, setAlerts] = useState<AlertSummary | null>(null);
  const [loading, setLoading] = useState(true);
  const [running, setRunning] = useState(false);
  const [statusFilter, setStatusFilter] = useState('PENDING');
  const [result, setResult] = useState<{ summary: string; ordersCreated: number } | null>(null);
  const [error, setError] = useState('');

  useEffect(() => { loadData(); }, [statusFilter]);

  async function loadData() {
    setLoading(true);
    const token = localStorage.getItem('homp_token');
    try {
      const [ordersRes, alertsRes] = await Promise.all([
        fetch(`${API_URL}/inventory-ai/orders?status=${statusFilter}`, {
          headers: { Authorization: `Bearer ${token}` },
        }),
        fetch(`${API_URL}/inventory-ai/alerts`, {
          headers: { Authorization: `Bearer ${token}` },
        }),
      ]);
      if (ordersRes.ok) setOrders(await ordersRes.json());
      if (alertsRes.ok) setAlerts(await alertsRes.json());
    } catch {
      setError('Could not load data');
    } finally {
      setLoading(false);
    }
  }

  async function runPrediction() {
    setRunning(true);
    setError('');
    setResult(null);
    const token = localStorage.getItem('homp_token');
    try {
      const res = await fetch(`${API_URL}/inventory-ai/predict`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.ok) {
        const data = await res.json();
        setResult(data);
        await loadData();
      } else {
        const err = await res.json();
        setError(err.message ?? 'Prediction failed');
      }
    } catch {
      setError('Network error');
    } finally {
      setRunning(false);
    }
  }

  async function updateStatus(id: string, status: 'APPROVED' | 'DISMISSED') {
    const token = localStorage.getItem('homp_token');
    await fetch(`${API_URL}/inventory-ai/orders/${id}`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ status }),
    });
    setOrders((prev) => prev.map((o) => o.id === id ? { ...o, status } : o));
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-gray-800">AI Inventory Prediction</h1>
          <p className="text-sm text-gray-500 mt-0.5">Auto purchase orders · runs every Monday at 6 AM</p>
        </div>
        <button
          onClick={runPrediction}
          disabled={running}
          className="flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium text-white disabled:opacity-60"
          style={{ backgroundColor: '#1E2A3A' }}
        >
          {running ? <><span className="animate-spin inline-block">⟳</span> Predicting…</> : <>📦 Run Prediction Now</>}
        </button>
      </div>

      {error && (
        <div className="bg-red-50 border border-red-200 rounded-lg px-4 py-3 text-sm text-red-700">{error}</div>
      )}

      {result && (
        <div className="bg-blue-50 border border-blue-100 rounded-xl px-5 py-4">
          <p className="font-semibold text-blue-800">
            {result.ordersCreated} purchase order{result.ordersCreated !== 1 ? 's' : ''} generated
          </p>
          <p className="text-sm text-blue-600 mt-0.5">{result.summary}</p>
        </div>
      )}

      {/* Stats */}
      <div className="grid grid-cols-3 gap-4">
        <div className="bg-white rounded-xl border shadow p-4">
          <p className="text-xs text-gray-500 mb-1">Total Stock Items</p>
          <p className="text-3xl font-bold text-gray-800">{alerts?.total ?? 0}</p>
        </div>
        <div
          className="bg-white rounded-xl border shadow p-4"
          style={{ borderLeftWidth: 3, borderLeftColor: '#F44336' }}
        >
          <p className="text-xs text-gray-500 mb-1">Below Reorder Level</p>
          <p className="text-3xl font-bold" style={{ color: '#F44336' }}>
            {alerts?.belowReorderCount ?? 0}
          </p>
          <p className="text-xs text-gray-400 mt-1">need restocking</p>
        </div>
        <div className="bg-white rounded-xl border shadow p-4">
          <p className="text-xs text-gray-500 mb-1">Pending Orders</p>
          <p className="text-3xl font-bold text-gray-800">
            {orders.filter((o) => o.status === 'PENDING').length}
          </p>
          <p className="text-xs text-gray-400 mt-1">awaiting approval</p>
        </div>
      </div>

      {/* Low Stock Alert Banner */}
      {alerts && alerts.belowReorderCount > 0 && (
        <div className="bg-red-50 border border-red-200 rounded-xl p-4">
          <p className="font-semibold text-red-700 mb-2">
            ⚠️ {alerts.belowReorderCount} item{alerts.belowReorderCount !== 1 ? 's' : ''} below reorder level
          </p>
          <div className="flex flex-wrap gap-2">
            {alerts.belowReorder.map((item) => (
              <span
                key={item.id}
                className="text-xs px-2 py-1 bg-red-100 text-red-700 rounded-full"
              >
                {item.name}: {Number(item.currentQty).toFixed(1)} {item.unit} (min: {Number(item.reorderLevel).toFixed(1)})
              </span>
            ))}
          </div>
        </div>
      )}

      {/* Purchase Orders Table */}
      <div className="bg-white rounded-xl border shadow">
        <div className="px-5 py-4 border-b flex items-center justify-between">
          <h2 className="font-semibold text-gray-700">Purchase Orders</h2>
          <div className="flex gap-1">
            {['PENDING', 'APPROVED', 'DISMISSED'].map((s) => (
              <button
                key={s}
                onClick={() => setStatusFilter(s)}
                className="px-3 py-1 rounded-lg text-xs font-medium transition-all"
                style={{
                  backgroundColor: statusFilter === s ? '#1E2A3A' : '#F5F6FA',
                  color: statusFilter === s ? '#fff' : '#64748b',
                }}
              >
                {s}
              </button>
            ))}
          </div>
        </div>

        {loading ? (
          <div className="py-12 text-center text-gray-400">Loading…</div>
        ) : orders.length === 0 ? (
          <div className="py-16 text-center text-gray-400">
            <div className="text-4xl mb-3">📦</div>
            <p className="font-medium text-gray-600">No {statusFilter.toLowerCase()} orders</p>
            <p className="text-sm mt-1">Click "Run Prediction Now" to generate AI purchase orders</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="bg-gray-50 text-left">
                  <th className="px-4 py-3 font-medium text-gray-500">Item</th>
                  <th className="px-4 py-3 font-medium text-gray-500 text-right">Current</th>
                  <th className="px-4 py-3 font-medium text-gray-500 text-right">Order Qty</th>
                  <th className="px-4 py-3 font-medium text-gray-500">Reason</th>
                  <th className="px-4 py-3 font-medium text-gray-500">Status</th>
                  <th className="px-4 py-3 font-medium text-gray-500">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y">
                {orders.map((order) => {
                  const style = STATUS_STYLE[order.status] ?? STATUS_STYLE.PENDING;
                  return (
                    <tr key={order.id} className="hover:bg-gray-50">
                      <td className="px-4 py-3">
                        <p className="font-medium text-gray-800">{order.itemName}</p>
                        {order.aiGenerated && (
                          <span className="text-xs text-blue-500">🤖 AI generated</span>
                        )}
                      </td>
                      <td className="px-4 py-3 text-right text-gray-600">
                        {Number(order.currentQty).toFixed(1)} {order.unit}
                      </td>
                      <td className="px-4 py-3 text-right font-semibold text-gray-800">
                        {Number(order.reorderQty).toFixed(1)} {order.unit}
                      </td>
                      <td className="px-4 py-3 text-gray-500 max-w-xs">
                        <p className="truncate">{order.reason}</p>
                      </td>
                      <td className="px-4 py-3">
                        <span
                          className="text-xs font-medium px-2 py-1 rounded-full"
                          style={{ backgroundColor: style.bg, color: style.text }}
                        >
                          {style.label}
                        </span>
                      </td>
                      <td className="px-4 py-3">
                        {order.status === 'PENDING' && (
                          <div className="flex gap-1">
                            <button
                              onClick={() => updateStatus(order.id, 'APPROVED')}
                              className="text-xs px-2 py-1 bg-green-50 text-green-700 rounded border border-green-200 hover:bg-green-100"
                            >
                              Approve
                            </button>
                            <button
                              onClick={() => updateStatus(order.id, 'DISMISSED')}
                              className="text-xs px-2 py-1 bg-gray-50 text-gray-600 rounded border border-gray-200 hover:bg-gray-100"
                            >
                              Dismiss
                            </button>
                          </div>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
