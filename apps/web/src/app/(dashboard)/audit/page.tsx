'use client';

import { useState, useEffect, useCallback } from 'react';
import { API_URL } from '@/lib/config';

interface AuditLog {
  id: string;
  eventType: string;
  resourceType: string;
  resourceId: string;
  diffJson: Record<string, unknown> | null;
  createdAt: string;
  actor: { name: string; email: string; role: string };
}

interface Stats {
  total: number;
  todayCount: number;
  byType: { eventType: string; count: number }[];
  byResource: { resourceType: string; count: number }[];
}

const EVENT_STYLE: Record<string, { bg: string; text: string }> = {
  CREATE:   { bg: '#E8F5E9', text: '#2E7D32' },
  UPDATE:   { bg: '#E3F2FD', text: '#1565C0' },
  DELETE:   { bg: '#FFEBEE', text: '#C62828' },
  APPROVE:  { bg: '#F3E5F5', text: '#7B1FA2' },
  DISBURSE: { bg: '#E0F2F1', text: '#00695C' },
  VALIDATE: { bg: '#FFF8E1', text: '#F57F17' },
  LOGIN:    { bg: '#F5F6FA', text: '#64748b' },
};

function timeAgo(date: string) {
  const diff = Date.now() - new Date(date).getTime();
  const m = Math.floor(diff / 60000);
  if (m < 1) return 'just now';
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  return new Date(date).toLocaleDateString('en-GB', { day: '2-digit', month: 'short' });
}

export default function AuditPage() {
  const [logs, setLogs] = useState<AuditLog[]>([]);
  const [stats, setStats] = useState<Stats | null>(null);
  const [loading, setLoading] = useState(true);
  const [filterResource, setFilterResource] = useState('');
  const [filterEvent, setFilterEvent] = useState('');
  const [selectedLog, setSelectedLog] = useState<AuditLog | null>(null);

  const token = typeof window !== 'undefined' ? localStorage.getItem('homp_token') : '';

  const load = useCallback(async () => {
    setLoading(true);
    const params = new URLSearchParams({ limit: '150' });
    if (filterResource) params.set('resourceType', filterResource);
    if (filterEvent) params.set('eventType', filterEvent);
    const h = { Authorization: `Bearer ${token}` };
    const [lRes, sRes] = await Promise.all([
      fetch(`${API_URL}/audit/logs?${params}`, { headers: h }),
      fetch(`${API_URL}/audit/stats`, { headers: h }),
    ]);
    if (lRes.ok) setLogs(await lRes.json());
    if (sRes.ok) setStats(await sRes.json());
    setLoading(false);
  }, [filterResource, filterEvent, token]);

  useEffect(() => { load(); }, [load]);

  const resourceTypes = stats?.byResource.map((b) => b.resourceType) ?? [];
  const eventTypes = stats?.byType.map((b) => b.eventType) ?? [];

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-gray-800">Audit Log</h1>
          <p className="text-sm text-gray-500 mt-0.5">Immutable record of all system actions</p>
        </div>
        <button onClick={load} className="text-xs px-3 py-1.5 border rounded-lg text-gray-500 hover:bg-gray-50">
          🔄 Refresh
        </button>
      </div>

      {/* Stats */}
      {stats && (
        <div className="grid grid-cols-4 gap-4">
          <div className="bg-white rounded-xl border shadow-sm p-4">
            <p className="text-xs text-gray-500">Total Events</p>
            <p className="text-2xl font-bold text-gray-800 mt-1">{stats.total.toLocaleString()}</p>
          </div>
          <div className="bg-white rounded-xl border shadow-sm p-4">
            <p className="text-xs text-gray-500">Today</p>
            <p className="text-2xl font-bold text-gray-800 mt-1">{stats.todayCount}</p>
          </div>
          <div className="bg-white rounded-xl border shadow-sm p-4 col-span-2">
            <p className="text-xs text-gray-500 mb-2">Events by Type</p>
            <div className="flex flex-wrap gap-2">
              {stats.byType.map((b) => {
                const s = EVENT_STYLE[b.eventType] ?? EVENT_STYLE.LOGIN;
                return (
                  <span key={b.eventType} className="text-xs px-2 py-0.5 rounded-full font-medium"
                    style={{ backgroundColor: s.bg, color: s.text }}>
                    {b.eventType} ({b.count})
                  </span>
                );
              })}
            </div>
          </div>
        </div>
      )}

      {/* Filters */}
      <div className="flex gap-3">
        <select
          value={filterResource}
          onChange={(e) => setFilterResource(e.target.value)}
          className="border rounded-lg px-3 py-2 text-sm text-gray-600"
        >
          <option value="">All Resources</option>
          {resourceTypes.map((r) => <option key={r} value={r}>{r}</option>)}
        </select>
        <select
          value={filterEvent}
          onChange={(e) => setFilterEvent(e.target.value)}
          className="border rounded-lg px-3 py-2 text-sm text-gray-600"
        >
          <option value="">All Events</option>
          {eventTypes.map((e) => <option key={e} value={e}>{e}</option>)}
        </select>
        {(filterResource || filterEvent) && (
          <button onClick={() => { setFilterResource(''); setFilterEvent(''); }}
            className="text-xs px-3 py-2 text-red-500 hover:underline">
            Clear filters
          </button>
        )}
      </div>

      {/* Log table + detail panel */}
      <div className="flex gap-4">
        {/* Table */}
        <div className="flex-1 bg-white rounded-xl border shadow-sm overflow-hidden">
          {loading ? (
            <p className="text-sm text-gray-400 p-6">Loading…</p>
          ) : logs.length === 0 ? (
            <div className="p-10 text-center text-gray-400">
              <div className="text-4xl mb-2">📋</div>
              <p>No audit logs yet</p>
              <p className="text-xs mt-1">Actions you take in the system will appear here</p>
            </div>
          ) : (
            <div className="overflow-y-auto" style={{ maxHeight: '60vh' }}>
              <table className="w-full text-sm">
                <thead className="sticky top-0 bg-gray-50 z-10">
                  <tr className="text-left border-b">
                    <th className="px-4 py-3 font-medium text-gray-500">Time</th>
                    <th className="px-4 py-3 font-medium text-gray-500">Event</th>
                    <th className="px-4 py-3 font-medium text-gray-500">Resource</th>
                    <th className="px-4 py-3 font-medium text-gray-500">Actor</th>
                    <th className="px-4 py-3 font-medium text-gray-500">ID</th>
                  </tr>
                </thead>
                <tbody className="divide-y">
                  {logs.map((log) => {
                    const s = EVENT_STYLE[log.eventType] ?? EVENT_STYLE.LOGIN;
                    const isSelected = selectedLog?.id === log.id;
                    return (
                      <tr
                        key={log.id}
                        onClick={() => setSelectedLog(isSelected ? null : log)}
                        className="hover:bg-gray-50 cursor-pointer transition-colors"
                        style={{ backgroundColor: isSelected ? '#F0F4FF' : undefined }}
                      >
                        <td className="px-4 py-2.5 text-xs text-gray-400 whitespace-nowrap">
                          {timeAgo(log.createdAt)}
                        </td>
                        <td className="px-4 py-2.5">
                          <span className="text-xs px-2 py-0.5 rounded-full font-medium"
                            style={{ backgroundColor: s.bg, color: s.text }}>
                            {log.eventType}
                          </span>
                        </td>
                        <td className="px-4 py-2.5 text-xs text-gray-600 font-mono">{log.resourceType}</td>
                        <td className="px-4 py-2.5">
                          <p className="text-xs font-medium text-gray-700">{log.actor?.name ?? '—'}</p>
                          <p className="text-xs text-gray-400">{log.actor?.role ?? ''}</p>
                        </td>
                        <td className="px-4 py-2.5 text-xs text-gray-400 font-mono">
                          {log.resourceId.slice(0, 8)}…
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>

        {/* Detail panel */}
        {selectedLog && (
          <div className="w-72 bg-white rounded-xl border shadow-sm p-5 flex-shrink-0 self-start sticky top-4">
            <div className="flex items-center justify-between mb-4">
              <h3 className="font-semibold text-gray-700 text-sm">Event Detail</h3>
              <button onClick={() => setSelectedLog(null)} className="text-gray-400 hover:text-gray-600 text-xs">✕</button>
            </div>
            <div className="space-y-3 text-xs">
              <div>
                <p className="text-gray-400">Event Type</p>
                <span className="px-2 py-0.5 rounded-full font-medium mt-0.5 inline-block"
                  style={{ backgroundColor: (EVENT_STYLE[selectedLog.eventType] ?? EVENT_STYLE.LOGIN).bg, color: (EVENT_STYLE[selectedLog.eventType] ?? EVENT_STYLE.LOGIN).text }}>
                  {selectedLog.eventType}
                </span>
              </div>
              <div>
                <p className="text-gray-400">Resource</p>
                <p className="font-mono text-gray-700">{selectedLog.resourceType}</p>
              </div>
              <div>
                <p className="text-gray-400">Resource ID</p>
                <p className="font-mono text-gray-600 break-all">{selectedLog.resourceId}</p>
              </div>
              <div>
                <p className="text-gray-400">Actor</p>
                <p className="font-medium text-gray-700">{selectedLog.actor?.name}</p>
                <p className="text-gray-400">{selectedLog.actor?.email}</p>
                <p className="text-gray-400">{selectedLog.actor?.role}</p>
              </div>
              <div>
                <p className="text-gray-400">Timestamp</p>
                <p className="text-gray-700">{new Date(selectedLog.createdAt).toLocaleString()}</p>
              </div>
              {selectedLog.diffJson && Object.keys(selectedLog.diffJson).length > 0 && (
                <div>
                  <p className="text-gray-400 mb-1">Diff / Payload</p>
                  <pre className="bg-gray-50 rounded-lg p-2 text-xs text-gray-600 overflow-auto max-h-48 whitespace-pre-wrap">
                    {JSON.stringify(selectedLog.diffJson, null, 2)}
                  </pre>
                </div>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
