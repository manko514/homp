'use client';

import { useState } from 'react';
import useSWR from 'swr';
import { fetcher, downloadPdf } from '@/lib/api';
import { StatCard } from '@/components/StatCard';
import { Spinner } from '@/components/Spinner';
import { Badge } from '@/components/Badge';

interface Revenue {
  date: string;
  totalRevenue: number;
  hotel: { revenue: number; checkouts: number };
  restaurant: { revenue: number; orders: number };
  bar: { revenue: number; sales: number };
}

interface StockReportItem {
  id: string;
  name: string;
  category: string;
  unit: string;
  currentQty: number;
  reorderLevel: number;
  status: 'OK' | 'LOW_STOCK' | 'OUT_OF_STOCK';
}

interface StockReport {
  generatedAt: string;
  totalItems: number;
  lowStockCount: number;
  items: StockReportItem[];
}

function stockBadge(status: string) {
  const m: Record<string, 'green' | 'yellow' | 'red'> = {
    OK: 'green', LOW_STOCK: 'yellow', OUT_OF_STOCK: 'red',
  };
  return m[status] ?? 'gray' as 'gray';
}

export default function ReportsPage() {
  const [date, setDate] = useState(new Date().toISOString().split('T')[0]);

  const { data: revenue, isLoading: revLoading } = useSWR<Revenue>(
    `/reports/daily-revenue?date=${date}`,
    fetcher,
  );
  const { data: stockReport, isLoading: stockLoading } = useSWR<StockReport>(
    '/reports/stock',
    fetcher,
  );

  return (
    <div className="space-y-8">
      <h1 className="text-2xl font-bold text-gray-900">Reports</h1>

      {/* Daily Revenue */}
      <div>
        <div className="flex items-center gap-4 mb-4">
          <h2 className="text-base font-semibold text-gray-800">Daily Revenue</h2>
          <input
            type="date"
            value={date}
            onChange={(e) => setDate(e.target.value)}
            className="border border-gray-300 rounded-md px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-600"
          />
          <button
            onClick={() => downloadPdf(`/reports/daily-revenue/pdf?date=${date}`)}
            className="ml-auto text-sm bg-brand-700 text-white rounded-md px-4 py-1.5 hover:bg-brand-600"
          >
            Download PDF
          </button>
        </div>

        {revLoading ? <Spinner /> : revenue ? (
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            <StatCard
              label="Total Revenue"
              value={`$${revenue.totalRevenue.toFixed(2)}`}
              sub={revenue.date}
            />
            <StatCard
              label="Hotel"
              value={`$${revenue.hotel.revenue.toFixed(2)}`}
              sub={`${revenue.hotel.checkouts} check-outs`}
            />
            <StatCard
              label="Restaurant"
              value={`$${revenue.restaurant.revenue.toFixed(2)}`}
              sub={`${revenue.restaurant.orders} orders billed`}
            />
            <StatCard
              label="Bar"
              value={`$${revenue.bar.revenue.toFixed(2)}`}
              sub={`${revenue.bar.sales} sales`}
            />
          </div>
        ) : null}
      </div>

      {/* Stock Report */}
      <div>
        <div className="flex items-center gap-4 mb-4">
          <h2 className="text-base font-semibold text-gray-800">Stock Report</h2>
          {stockReport && (
            <span className="text-xs text-gray-400">
              {stockReport.totalItems} items — {stockReport.lowStockCount} low/out
            </span>
          )}
          <button
            onClick={() => downloadPdf('/reports/stock/pdf')}
            className="ml-auto text-sm bg-brand-700 text-white rounded-md px-4 py-1.5 hover:bg-brand-600"
          >
            Download PDF
          </button>
        </div>

        {stockLoading ? <Spinner /> : (
          <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  {['Item', 'Category', 'Current Stock', 'Reorder Level', 'Status'].map((h) => (
                    <th key={h} className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wider">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {(stockReport?.items ?? []).map((item) => (
                  <tr key={item.id} className={`hover:bg-gray-50 ${item.status !== 'OK' ? 'bg-yellow-50/40' : ''}`}>
                    <td className="px-4 py-3 font-medium text-gray-900">{item.name}</td>
                    <td className="px-4 py-3 text-gray-600">{item.category}</td>
                    <td className={`px-4 py-3 font-semibold ${item.status === 'OK' ? 'text-gray-800' : 'text-red-600'}`}>
                      {item.currentQty} {item.unit}
                    </td>
                    <td className="px-4 py-3 text-gray-500">{item.reorderLevel} {item.unit}</td>
                    <td className="px-4 py-3"><Badge label={item.status.replace('_', ' ')} variant={stockBadge(item.status)} /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
