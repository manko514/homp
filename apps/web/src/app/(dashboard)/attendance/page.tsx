'use client';

import { useState, useEffect, useCallback } from 'react';
import { API_URL } from '@/lib/config';

interface AttendanceRecord {
  id: string;
  userId: string;
  clockIn: string;
  clockOut: string | null;
  clockInLat: number | null;
  clockInLng: number | null;
  clockOutLat: number | null;
  clockOutLng: number | null;
  user?: { name: string; role: string; email: string };
}

const ROLE_COLORS: Record<string, { bg: string; text: string }> = {
  WAITER:      { bg: '#E3F2FD', text: '#1565C0' },
  BARTENDER:   { bg: '#FCE4EC', text: '#880E4F' },
  HOUSEKEEPER: { bg: '#E8F5E9', text: '#1B5E20' },
  MANAGER:     { bg: '#FFF3E0', text: '#E65100' },
  ADMIN:       { bg: '#F3E5F5', text: '#4A148C' },
};

function fmtTime(iso: string | null) {
  if (!iso) return '—';
  return new Date(iso).toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' });
}

function duration(clockIn: string, clockOut: string | null) {
  if (!clockOut) return 'On shift';
  const ms = new Date(clockOut).getTime() - new Date(clockIn).getTime();
  const h = Math.floor(ms / 3600000);
  const m = Math.floor((ms % 3600000) / 60000);
  return `${h}h ${m}m`;
}

function gpsLink(lat: number | null, lng: number | null) {
  if (!lat || !lng) return null;
  return `https://www.google.com/maps?q=${lat},${lng}`;
}

export default function AttendancePage() {
  const [records, setRecords] = useState<AttendanceRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [date, setDate] = useState(new Date().toISOString().slice(0, 10));
  const [roleFilter, setRoleFilter] = useState('ALL');

  const token = typeof window !== 'undefined' ? localStorage.getItem('homp_token') : '';

  const load = useCallback(async () => {
    setLoading(true);
    const res = await fetch(`${API_URL}/staff/attendance?date=${date}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (res.ok) {
      setRecords(await res.json());
    }
    setLoading(false);
  }, [date, token]);

  useEffect(() => { load(); }, [load]);

  const roles = ['ALL', 'WAITER', 'BARTENDER', 'HOUSEKEEPER', 'MANAGER', 'ADMIN'];
  const filtered = roleFilter === 'ALL'
    ? records
    : records.filter((r) => r.user?.role === roleFilter);

  const onShift = records.filter((r) => !r.clockOut).length;

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-bold text-gray-800">Staff Attendance</h1>
          <p className="text-sm text-gray-500 mt-0.5">Clock-in/out log with GPS verification</p>
        </div>
        <div className="flex items-center gap-3">
          <input
            type="date"
            value={date}
            max={new Date().toISOString().slice(0, 10)}
            onChange={(e) => setDate(e.target.value)}
            className="border rounded-lg px-3 py-2 text-sm"
          />
          <button
            onClick={load}
            className="px-4 py-2 rounded-lg text-sm font-medium text-white"
            style={{ backgroundColor: '#1E2A3A' }}
          >
            Refresh
          </button>
        </div>
      </div>

      {/* Summary chips */}
      <div className="flex gap-4 flex-wrap">
        <div className="bg-white rounded-xl border shadow-sm px-5 py-3 flex items-center gap-3">
          <span className="text-2xl font-bold text-gray-800">{records.length}</span>
          <span className="text-sm text-gray-500">Total shifts</span>
        </div>
        <div className="bg-white rounded-xl border shadow-sm px-5 py-3 flex items-center gap-3">
          <span className="text-2xl font-bold" style={{ color: '#2E7D32' }}>{onShift}</span>
          <span className="text-sm text-gray-500">Currently on shift</span>
        </div>
        <div className="bg-white rounded-xl border shadow-sm px-5 py-3 flex items-center gap-3">
          <span className="text-2xl font-bold text-gray-800">{records.length - onShift}</span>
          <span className="text-sm text-gray-500">Clocked out</span>
        </div>
      </div>

      {/* Role filter */}
      <div className="flex gap-1 flex-wrap">
        {roles.map((r) => (
          <button
            key={r}
            onClick={() => setRoleFilter(r)}
            className="px-3 py-1.5 rounded-lg text-xs font-medium transition-colors"
            style={{
              backgroundColor: roleFilter === r ? '#1E2A3A' : '#F5F6FA',
              color: roleFilter === r ? '#fff' : '#64748b',
            }}
          >
            {r}
          </button>
        ))}
      </div>

      {/* Table */}
      <div className="bg-white rounded-xl border shadow-sm overflow-x-auto">
        {loading ? (
          <p className="text-sm text-gray-400 p-6">Loading…</p>
        ) : filtered.length === 0 ? (
          <div className="p-10 text-center text-gray-400">
            <div className="text-4xl mb-2">📋</div>
            <p>No attendance records for this date</p>
          </div>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-gray-50 text-left border-b">
                <th className="px-4 py-3 font-medium text-gray-500">Staff Member</th>
                <th className="px-4 py-3 font-medium text-gray-500">Role</th>
                <th className="px-4 py-3 font-medium text-gray-500">Clock In</th>
                <th className="px-4 py-3 font-medium text-gray-500">Clock Out</th>
                <th className="px-4 py-3 font-medium text-gray-500">Duration</th>
                <th className="px-4 py-3 font-medium text-gray-500">GPS In</th>
                <th className="px-4 py-3 font-medium text-gray-500">GPS Out</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {filtered.map((r) => {
                const roleStyle = ROLE_COLORS[r.user?.role ?? ''] ?? { bg: '#F5F6FA', text: '#64748b' };
                const isActive = !r.clockOut;
                return (
                  <tr key={r.id} className="hover:bg-gray-50">
                    <td className="px-4 py-3">
                      <p className="font-medium text-gray-800">{r.user?.name ?? r.userId.slice(0, 8)}</p>
                      <p className="text-xs text-gray-400">{r.user?.email ?? ''}</p>
                    </td>
                    <td className="px-4 py-3">
                      <span
                        className="px-2 py-0.5 rounded-full text-xs font-medium"
                        style={{ backgroundColor: roleStyle.bg, color: roleStyle.text }}
                      >
                        {r.user?.role ?? '—'}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-gray-700 font-mono text-xs">{fmtTime(r.clockIn)}</td>
                    <td className="px-4 py-3">
                      {isActive ? (
                        <span className="flex items-center gap-1.5 text-xs font-medium" style={{ color: '#2E7D32' }}>
                          <span className="w-2 h-2 rounded-full bg-green-500 animate-pulse inline-block" />
                          On shift
                        </span>
                      ) : (
                        <span className="font-mono text-xs text-gray-700">{fmtTime(r.clockOut)}</span>
                      )}
                    </td>
                    <td className="px-4 py-3 text-xs text-gray-600">{duration(r.clockIn, r.clockOut)}</td>
                    <td className="px-4 py-3">
                      {gpsLink(r.clockInLat, r.clockInLng) ? (
                        <a
                          href={gpsLink(r.clockInLat, r.clockInLng)!}
                          target="_blank"
                          rel="noreferrer"
                          className="text-xs text-blue-600 hover:underline"
                        >
                          {r.clockInLat?.toFixed(4)}, {r.clockInLng?.toFixed(4)}
                        </a>
                      ) : (
                        <span className="text-xs text-gray-400">—</span>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      {gpsLink(r.clockOutLat, r.clockOutLng) ? (
                        <a
                          href={gpsLink(r.clockOutLat, r.clockOutLng)!}
                          target="_blank"
                          rel="noreferrer"
                          className="text-xs text-blue-600 hover:underline"
                        >
                          {r.clockOutLat?.toFixed(4)}, {r.clockOutLng?.toFixed(4)}
                        </a>
                      ) : (
                        <span className="text-xs text-gray-400">—</span>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
