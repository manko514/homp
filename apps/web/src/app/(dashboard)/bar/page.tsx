'use client';

import useSWR from 'swr';
import { fetcher } from '@/lib/api';
import { Badge } from '@/components/Badge';
import { Spinner } from '@/components/Spinner';

interface Drink { id: string; name: string; category: string; price: number; available: boolean }
interface Sale {
  id: string;
  qty: number;
  wasteQty: number;
  total: number;
  createdAt: string;
  drink: { name: string; category: string };
}
interface ShiftSummary {
  totalRevenue: number;
  totalDrinks: number;
  totalWaste: number;
  saleCount: number;
  byCategory: Record<string, number>;
}

const today = new Date().toISOString().split('T')[0];

export default function BarPage() {
  const { data: drinks, isLoading: dLoading } = useSWR<Drink[]>('/bar/drinks', fetcher);
  const { data: sales, isLoading: sLoading } = useSWR<Sale[]>('/bar/sales', fetcher);
  const { data: summary } = useSWR<ShiftSummary>(`/bar/shift-summary?from=${today}T00:00:00`, fetcher);

  return (
    <div className="space-y-8">
      <h1 className="text-2xl font-bold text-gray-900">Bar</h1>

      {/* Today's shift summary */}
      {summary && (
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
          {[
            { label: 'Revenue Today', value: `$${summary.totalRevenue.toFixed(2)}` },
            { label: 'Drinks Sold', value: summary.totalDrinks },
            { label: 'Waste Units', value: summary.totalWaste },
            { label: 'Total Sales', value: summary.saleCount },
          ].map(({ label, value }) => (
            <div key={label} className="bg-white rounded-lg border border-gray-200 p-4 shadow-sm">
              <p className="text-xs text-gray-500 font-medium">{label}</p>
              <p className="text-2xl font-bold text-brand-700 mt-1">{value}</p>
            </div>
          ))}
        </div>
      )}

      {/* Drinks menu */}
      <div>
        <h2 className="text-base font-semibold text-gray-800 mb-3">Drinks Menu</h2>
        {dLoading ? <Spinner /> : (
          <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  {['Name', 'Category', 'Price', 'Status'].map((h) => (
                    <th key={h} className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wider">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {(drinks ?? []).map((d) => (
                  <tr key={d.id} className="hover:bg-gray-50">
                    <td className="px-4 py-3 font-medium text-gray-900">{d.name}</td>
                    <td className="px-4 py-3 text-gray-600">{d.category}</td>
                    <td className="px-4 py-3 text-gray-700">${Number(d.price).toFixed(2)}</td>
                    <td className="px-4 py-3">
                      <Badge label={d.available ? 'Available' : 'Unavailable'} variant={d.available ? 'green' : 'red'} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Recent sales */}
      <div>
        <h2 className="text-base font-semibold text-gray-800 mb-3">Recent Sales</h2>
        {sLoading ? <Spinner /> : (
          <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  {['Drink', 'Category', 'Qty', 'Waste', 'Total', 'Time'].map((h) => (
                    <th key={h} className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wider">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {(sales ?? []).slice(0, 20).map((s) => (
                  <tr key={s.id} className="hover:bg-gray-50">
                    <td className="px-4 py-3 font-medium text-gray-900">{s.drink.name}</td>
                    <td className="px-4 py-3 text-gray-600">{s.drink.category}</td>
                    <td className="px-4 py-3 text-gray-700">{s.qty}</td>
                    <td className="px-4 py-3 text-gray-500">{s.wasteQty}</td>
                    <td className="px-4 py-3 font-semibold text-gray-900">${Number(s.total).toFixed(2)}</td>
                    <td className="px-4 py-3 text-gray-400 text-xs">{new Date(s.createdAt).toLocaleTimeString()}</td>
                  </tr>
                ))}
                {(sales?.length ?? 0) === 0 && (
                  <tr><td colSpan={6} className="px-4 py-6 text-center text-gray-400">No sales recorded yet.</td></tr>
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
