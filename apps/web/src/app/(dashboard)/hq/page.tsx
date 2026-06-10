'use client';

import { useState, useEffect } from 'react';
import { API_URL } from '@/lib/config';

interface PropertyKpi {
  tenantId: string;
  name: string;
  revenue30d: number;
  hotelRevenue: number;
  fbnRevenue: number;
  barRevenue: number;
  reservations: number;
  occupancyRate: number;
}

interface GroupKpi {
  groupId: string;
  groupName: string;
  properties: number;
  totalRevenue30d: number;
  totalEmployees: number;
  openAnomalyAlerts: number;
  byProperty: PropertyKpi[];
}

export default function HqPage() {
  const [groups, setGroups] = useState<GroupKpi[]>([]);
  const [selected, setSelected] = useState<GroupKpi | null>(null);
  const [grandTotal, setGrandTotal] = useState(0);
  const [loading, setLoading] = useState(true);

  useEffect(() => { load(); }, []);

  async function load() {
    const token = localStorage.getItem('homp_token');
    const headers = { Authorization: `Bearer ${token}` };
    try {
      const res = await fetch(`${API_URL}/hq/consolidated`, { headers });
      if (!res.ok) return;
      const data = await res.json();
      setGroups(data.groups ?? []);
      setGrandTotal(data.grandTotalRevenue30d ?? 0);
      if (data.groups?.length) setSelected(data.groups[0]);
    } finally {
      setLoading(false);
    }
  }

  const fmt = (n: number) =>
    n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-gray-800">HQ Dashboard</h1>
          <p className="text-sm text-gray-500 mt-0.5">Cross-property KPIs · consolidated P&amp;L · last 30 days</p>
        </div>
        <div className="bg-white rounded-xl border shadow px-5 py-3 text-right">
          <p className="text-xs text-gray-400">Grand Total Revenue (30d)</p>
          <p className="text-2xl font-bold text-gray-800">${fmt(grandTotal)}</p>
        </div>
      </div>

      {loading ? (
        <div className="text-center py-20 text-gray-400">Loading HQ data…</div>
      ) : groups.length === 0 ? (
        <div className="bg-white rounded-xl border shadow p-10 text-center text-gray-400">
          <p className="text-4xl mb-3">🏢</p>
          <p className="font-medium">No property groups configured</p>
          <p className="text-sm mt-1">Create a PropertyGroup and link tenants to it via the API or database seed.</p>
        </div>
      ) : (
        <div className="flex gap-5">
          {/* Group selector */}
          <div className="w-56 flex-shrink-0 space-y-2">
            {groups.map((g) => (
              <button
                key={g.groupId}
                onClick={() => setSelected(g)}
                className="w-full text-left p-4 rounded-xl border shadow-sm transition-all"
                style={{
                  backgroundColor: selected?.groupId === g.groupId ? '#1E2A3A' : 'white',
                  borderColor: selected?.groupId === g.groupId ? '#1E2A3A' : '#e5e7eb',
                }}
              >
                <p className="font-semibold text-sm" style={{ color: selected?.groupId === g.groupId ? '#fff' : '#1E2A3A' }}>
                  {g.groupName}
                </p>
                <p className="text-xs mt-1" style={{ color: selected?.groupId === g.groupId ? '#aaa' : '#94a3b8' }}>
                  {g.properties} propert{g.properties === 1 ? 'y' : 'ies'}
                </p>
              </button>
            ))}
          </div>

          {/* Group detail */}
          {selected && (
            <div className="flex-1 space-y-5">
              {/* KPI chips */}
              <div className="grid grid-cols-4 gap-4">
                {[
                  { label: 'Revenue (30d)', value: `$${fmt(selected.totalRevenue30d)}`, color: '#4CAF50' },
                  { label: 'Properties', value: selected.properties.toString(), color: '#2196F3' },
                  { label: 'Employees', value: selected.totalEmployees.toString(), color: '#FF9800' },
                  { label: 'Open Alerts', value: selected.openAnomalyAlerts.toString(), color: selected.openAnomalyAlerts > 0 ? '#F44336' : '#4CAF50' },
                ].map((s) => (
                  <div key={s.label} className="bg-white rounded-xl border shadow p-4">
                    <p className="text-xs text-gray-400 mb-1">{s.label}</p>
                    <p className="text-2xl font-bold" style={{ color: s.color }}>{s.value}</p>
                  </div>
                ))}
              </div>

              {/* Per-property P&L table */}
              <div className="bg-white rounded-xl border shadow overflow-hidden">
                <div className="px-5 py-4 border-b">
                  <h2 className="font-semibold text-gray-700">Property P&amp;L Breakdown</h2>
                </div>
                <table className="w-full text-sm">
                  <thead>
                    <tr className="bg-gray-50 text-left">
                      <th className="px-4 py-3 font-medium text-gray-500">Property</th>
                      <th className="px-4 py-3 font-medium text-gray-500 text-right">Hotel Rev.</th>
                      <th className="px-4 py-3 font-medium text-gray-500 text-right">F&amp;B Rev.</th>
                      <th className="px-4 py-3 font-medium text-gray-500 text-right">Bar Rev.</th>
                      <th className="px-4 py-3 font-medium text-gray-500 text-right">Total</th>
                      <th className="px-4 py-3 font-medium text-gray-500 text-right">Occupancy</th>
                      <th className="px-4 py-3 font-medium text-gray-500 text-right">Bookings</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y">
                    {selected.byProperty.map((p) => (
                      <tr key={p.tenantId} className="hover:bg-gray-50">
                        <td className="px-4 py-3 font-medium text-gray-800">{p.name}</td>
                        <td className="px-4 py-3 text-right text-gray-600">${fmt(p.hotelRevenue)}</td>
                        <td className="px-4 py-3 text-right text-gray-600">${fmt(p.fbnRevenue)}</td>
                        <td className="px-4 py-3 text-right text-gray-600">${fmt(p.barRevenue)}</td>
                        <td className="px-4 py-3 text-right font-bold text-gray-800">${fmt(p.revenue30d)}</td>
                        <td className="px-4 py-3 text-right">
                          <span
                            className="text-xs font-semibold px-2 py-0.5 rounded-full"
                            style={{
                              backgroundColor: p.occupancyRate >= 70 ? '#E8F5E9' : '#FFF8E1',
                              color: p.occupancyRate >= 70 ? '#2E7D32' : '#F9A825',
                            }}
                          >
                            {p.occupancyRate}%
                          </span>
                        </td>
                        <td className="px-4 py-3 text-right text-gray-600">{p.reservations}</td>
                      </tr>
                    ))}
                    {/* Total row */}
                    <tr className="bg-gray-50 font-bold">
                      <td className="px-4 py-3 text-gray-700">Total</td>
                      <td className="px-4 py-3 text-right text-gray-700">
                        ${fmt(selected.byProperty.reduce((s, p) => s + p.hotelRevenue, 0))}
                      </td>
                      <td className="px-4 py-3 text-right text-gray-700">
                        ${fmt(selected.byProperty.reduce((s, p) => s + p.fbnRevenue, 0))}
                      </td>
                      <td className="px-4 py-3 text-right text-gray-700">
                        ${fmt(selected.byProperty.reduce((s, p) => s + p.barRevenue, 0))}
                      </td>
                      <td className="px-4 py-3 text-right text-green-600">${fmt(selected.totalRevenue30d)}</td>
                      <td colSpan={2} />
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
