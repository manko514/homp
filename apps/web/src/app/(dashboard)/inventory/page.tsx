'use client';

import { useState } from 'react';
import useSWR from 'swr';
import { fetcher, api } from '@/lib/api';
import { Badge } from '@/components/Badge';
import { Spinner } from '@/components/Spinner';
import { Modal } from '@/components/Modal';

interface StockItem {
  id: string;
  name: string;
  category: string;
  unit: string;
  currentQty: number;
  reorderLevel: number;
}

type MovementType = 'STOCK_IN' | 'STOCK_OUT' | 'WASTE' | 'ADJUSTMENT';

function stockBadge(item: StockItem) {
  if (item.currentQty <= 0) return <Badge label="Out of Stock" variant="red" />;
  if (item.currentQty <= item.reorderLevel) return <Badge label="Low Stock" variant="yellow" />;
  return <Badge label="OK" variant="green" />;
}

export default function InventoryPage() {
  const { data: items, isLoading, mutate } = useSWR<StockItem[]>('/inventory/stock', fetcher);
  const [open, setOpen] = useState(false);
  const [selectedId, setSelectedId] = useState('');
  const [movementType, setMovementType] = useState<MovementType>('STOCK_IN');
  const [qty, setQty] = useState('');
  const [notes, setNotes] = useState('');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  const byCategory = (items ?? []).reduce(
    (acc, i) => {
      if (!acc[i.category]) acc[i.category] = [];
      acc[i.category].push(i);
      return acc;
    },
    {} as Record<string, StockItem[]>,
  );

  async function submitMovement() {
    setError('');
    setSaving(true);
    try {
      await api.post('/inventory/movements', {
        stockItemId: selectedId,
        movementType,
        qty: parseFloat(qty),
        notes: notes || undefined,
      });
      await mutate();
      setOpen(false);
      setQty('');
      setNotes('');
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Failed');
    } finally {
      setSaving(false);
    }
  }

  function openModal(id: string) {
    setSelectedId(id);
    setMovementType('STOCK_IN');
    setQty('');
    setNotes('');
    setError('');
    setOpen(true);
  }

  const selectedItem = items?.find((i) => i.id === selectedId);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">Inventory</h1>
      </div>

      {isLoading ? <Spinner /> : (
        Object.entries(byCategory).map(([category, catItems]) => (
          <div key={category}>
            <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-2">{category}</h2>
            <div className="bg-white rounded-lg border border-gray-200 overflow-hidden mb-4">
              <table className="w-full text-sm">
                <thead className="bg-gray-50 border-b border-gray-200">
                  <tr>
                    {['Item', 'Current Stock', 'Reorder Level', 'Status', ''].map((h) => (
                      <th key={h} className="text-left px-4 py-2.5 text-xs font-semibold text-gray-500 uppercase tracking-wider">{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {catItems.map((item) => (
                    <tr key={item.id} className="hover:bg-gray-50">
                      <td className="px-4 py-3 font-medium text-gray-900">{item.name}</td>
                      <td className={`px-4 py-3 font-semibold ${item.currentQty <= item.reorderLevel ? 'text-red-600' : 'text-gray-800'}`}>
                        {Number(item.currentQty).toFixed(2)} {item.unit}
                      </td>
                      <td className="px-4 py-3 text-gray-500">{Number(item.reorderLevel).toFixed(2)} {item.unit}</td>
                      <td className="px-4 py-3">{stockBadge(item)}</td>
                      <td className="px-4 py-3 text-right">
                        <button
                          onClick={() => openModal(item.id)}
                          className="text-xs text-brand-700 hover:underline font-medium"
                        >
                          + Movement
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        ))
      )}

      {open && (
        <Modal title={`Record Movement — ${selectedItem?.name}`} onClose={() => setOpen(false)}>
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Type</label>
              <select
                value={movementType}
                onChange={(e) => setMovementType(e.target.value as MovementType)}
                className="w-full border border-gray-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-600"
              >
                <option value="STOCK_IN">Stock In (delivery)</option>
                <option value="STOCK_OUT">Stock Out (manual removal)</option>
                <option value="WASTE">Waste</option>
                <option value="ADJUSTMENT">Adjustment (inventory count)</option>
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Quantity ({selectedItem?.unit})
              </label>
              <input
                type="number"
                step="0.01"
                min="0.01"
                value={qty}
                onChange={(e) => setQty(e.target.value)}
                className="w-full border border-gray-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-600"
                placeholder="e.g. 2.5"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Notes (optional)</label>
              <input
                type="text"
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                className="w-full border border-gray-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-600"
                placeholder="e.g. Weekly delivery"
              />
            </div>
            {error && <p className="text-sm text-red-600 bg-red-50 rounded px-3 py-2">{error}</p>}
            <div className="flex gap-3 justify-end pt-2">
              <button onClick={() => setOpen(false)} className="text-sm text-gray-600 hover:text-gray-800 px-3 py-1.5">
                Cancel
              </button>
              <button
                onClick={submitMovement}
                disabled={saving || !qty}
                className="bg-brand-700 text-white text-sm rounded-md px-4 py-1.5 hover:bg-brand-600 disabled:opacity-50"
              >
                {saving ? 'Saving…' : 'Save'}
              </button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
