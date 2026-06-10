'use client';

import useSWR from 'swr';
import { fetcher } from '@/lib/api';
import { Badge } from '@/components/Badge';
import { Spinner } from '@/components/Spinner';

interface Table { id: string; tableNumber: number; capacity: number; status: string; qrCode: string }
interface OrderItem { qty: number; unitPrice: number; menuItem: { name: string } }
interface Order {
  id: string;
  status: string;
  total: number;
  createdAt: string;
  table?: { tableNumber: number };
  orderItems: OrderItem[];
}

function tableBadge(s: string) {
  const m: Record<string, 'green' | 'red' | 'gray'> = { AVAILABLE: 'green', OCCUPIED: 'red', RESERVED: 'yellow' as 'gray' };
  return m[s] ?? 'gray';
}

function orderBadge(s: string) {
  const m: Record<string, 'blue' | 'yellow' | 'green' | 'gray' | 'red'> = {
    PENDING: 'blue', KDS: 'yellow', READY: 'green', SERVED: 'gray', BILLED: 'gray', CANCELLED: 'red',
  };
  return m[s] ?? 'gray';
}

function qrImageUrl(payload: string) {
  return `https://quickchart.io/qr?text=${encodeURIComponent(payload)}&size=200`;
}

export default function RestaurantPage() {
  const { data: tables, isLoading: tLoading } = useSWR<Table[]>('/restaurant/tables', fetcher, { refreshInterval: 2000 });
  const { data: orders, isLoading: oLoading } = useSWR<Order[]>('/restaurant/orders', fetcher, { refreshInterval: 2000 });

  const activeOrders = orders?.filter((o) => !['BILLED', 'CANCELLED'].includes(o.status)) ?? [];

  return (
    <div className="space-y-8">
      <h1 className="text-2xl font-bold text-gray-900">Restaurant</h1>

      {/* Tables grid */}
      <div>
        <h2 className="text-base font-semibold text-gray-800 mb-3">Tables</h2>
        {tLoading ? <Spinner /> : (
          <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-6 gap-3">
            {tables?.map((t) => (
              <div key={t.id} className="bg-white border border-gray-200 rounded-lg p-3 shadow-sm text-center">
                <p className="text-xl font-bold text-gray-800">{t.tableNumber}</p>
                <p className="text-xs text-gray-400 mb-1">{t.capacity} seats</p>
                <Badge label={t.status} variant={tableBadge(t.status)} />
                {t.qrCode && (
                  <a
                    href={qrImageUrl(t.qrCode)}
                    target="_blank"
                    rel="noreferrer"
                    className="mt-2 block text-xs text-brand-600 hover:text-brand-700 underline"
                    title="Open QR code for printing"
                  >
                    🔲 Print QR
                  </a>
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Active orders — KDS view */}
      <div>
        <h2 className="text-base font-semibold text-gray-800 mb-3">Active Orders</h2>
        {oLoading ? <Spinner /> : activeOrders.length === 0 ? (
          <p className="text-sm text-gray-400">No active orders.</p>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {activeOrders.map((o) => (
              <div key={o.id} className="bg-white border border-gray-200 rounded-lg p-4 shadow-sm">
                <div className="flex justify-between items-start mb-2">
                  <div>
                    <p className="font-semibold text-gray-900">
                      {o.table ? `Table ${o.table.tableNumber}` : 'Room Service'}
                    </p>
                    <p className="text-xs text-gray-400">{new Date(o.createdAt).toLocaleTimeString()}</p>
                  </div>
                  <Badge label={o.status} variant={orderBadge(o.status)} />
                </div>
                <ul className="space-y-1 mt-2">
                  {o.orderItems?.map((i, idx) => (
                    <li key={idx} className="text-sm text-gray-700 flex justify-between">
                      <span>{i.menuItem?.name ?? '—'}</span>
                      <span className="text-gray-400">×{i.qty}</span>
                    </li>
                  ))}
                </ul>
                <p className="text-sm font-semibold text-brand-700 mt-3 text-right">${Number(o.total).toFixed(2)}</p>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
