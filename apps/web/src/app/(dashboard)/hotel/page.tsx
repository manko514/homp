'use client';

import { useState } from 'react';
import useSWR from 'swr';
import { fetcher, api } from '@/lib/api';
import { Badge } from '@/components/Badge';
import { Spinner } from '@/components/Spinner';

interface Room {
  id: string;
  roomNumber: string;
  type: string;
  floor: number;
  status: string;
  baseRate: number;
}

interface Reservation {
  id: string;
  roomId: string;
  checkIn: string;
  checkOut: string;
  status: string;
  totalAmount: number | null;
  guest?: { name: string; email: string };
  room?: { roomNumber: string };
}

function roomStatusBadge(status: string) {
  const map: Record<string, 'green' | 'red' | 'yellow' | 'gray'> = {
    AVAILABLE: 'green',
    OCCUPIED: 'red',
    CLEANING: 'yellow',
    MAINTENANCE: 'gray',
    OUT_OF_ORDER: 'gray',
  };
  return map[status] ?? 'gray';
}

function resBadge(status: string) {
  const map: Record<string, 'blue' | 'green' | 'gray' | 'red'> = {
    PENDING: 'blue', CONFIRMED: 'green', CHECKED_IN: 'green', CHECKED_OUT: 'gray', CANCELLED: 'red', NO_SHOW: 'red',
  };
  return map[status] ?? 'gray';
}

export default function HotelPage() {
  const { data: rooms, isLoading: roomsLoading } = useSWR<Room[]>('/hotel/rooms', fetcher);
  const { data: reservations, isLoading: resLoading, mutate } = useSWR<Reservation[]>('/hotel/reservations', fetcher);
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function doAction(reservationId: string, action: 'confirm' | 'checkin' | 'checkout' | 'cancel') {
    setActionLoading(reservationId + action);
    setError(null);
    try {
      await api.patch(`/hotel/reservations/${reservationId}/${action}`, {});
      await mutate();
    } catch (e: any) {
      setError(e.message ?? 'Action failed');
    } finally {
      setActionLoading(null);
    }
  }

  return (
    <div className="space-y-8">
      <h1 className="text-2xl font-bold text-gray-900">Hotel Management</h1>

      {error && (
        <div className="bg-red-50 border border-red-200 text-red-700 rounded-md px-4 py-3 text-sm">{error}</div>
      )}

      {/* Rooms */}
      <div>
        <h2 className="text-base font-semibold text-gray-800 mb-3">Rooms</h2>
        {roomsLoading ? (
          <Spinner />
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-3">
            {rooms?.map((room) => (
              <div key={room.id} className="bg-white border border-gray-200 rounded-lg p-4 shadow-sm">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-lg font-bold text-gray-900">{room.roomNumber}</span>
                  <Badge label={room.status} variant={roomStatusBadge(room.status)} />
                </div>
                <p className="text-xs text-gray-500">{room.type}</p>
                <p className="text-xs text-gray-400">Floor {room.floor}</p>
                <p className="text-sm font-semibold text-brand-700 mt-2">${Number(room.baseRate).toFixed(0)}/night</p>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Reservations */}
      <div>
        <h2 className="text-base font-semibold text-gray-800 mb-3">Reservations</h2>
        {resLoading ? (
          <Spinner />
        ) : (
          <div className="bg-white rounded-lg border border-gray-200 overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  {['Guest', 'Room', 'Check-in', 'Check-out', 'Status', 'Total', 'Actions'].map((h) => (
                    <th key={h} className="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wider">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {(reservations ?? []).map((r) => {
                  const busy = (a: string) => actionLoading === r.id + a;
                  return (
                    <tr key={r.id} className="hover:bg-gray-50">
                      <td className="px-4 py-3">
                        <p className="font-medium text-gray-900">{r.guest?.name ?? '—'}</p>
                        <p className="text-xs text-gray-400">{r.guest?.email ?? ''}</p>
                      </td>
                      <td className="px-4 py-3 text-gray-700">{r.room?.roomNumber ?? r.roomId.slice(0, 8)}</td>
                      <td className="px-4 py-3 text-gray-600">{new Date(r.checkIn).toLocaleDateString()}</td>
                      <td className="px-4 py-3 text-gray-600">{new Date(r.checkOut).toLocaleDateString()}</td>
                      <td className="px-4 py-3"><Badge label={r.status} variant={resBadge(r.status)} /></td>
                      <td className="px-4 py-3 text-gray-700">{r.totalAmount != null ? `$${Number(r.totalAmount).toFixed(2)}` : '—'}</td>
                      <td className="px-4 py-3">
                        <div className="flex gap-1 flex-wrap">
                          {r.status === 'PENDING' && (
                            <button
                              onClick={() => doAction(r.id, 'confirm')}
                              disabled={!!actionLoading}
                              className="text-xs px-2 py-1 rounded bg-blue-600 text-white hover:bg-blue-700 disabled:opacity-50"
                            >
                              {busy('confirm') ? '…' : 'Confirm'}
                            </button>
                          )}
                          {r.status === 'CONFIRMED' && (
                            <button
                              onClick={() => doAction(r.id, 'checkin')}
                              disabled={!!actionLoading}
                              className="text-xs px-2 py-1 rounded bg-green-600 text-white hover:bg-green-700 disabled:opacity-50"
                            >
                              {busy('checkin') ? '…' : 'Check In'}
                            </button>
                          )}
                          {r.status === 'CHECKED_IN' && (
                            <button
                              onClick={() => doAction(r.id, 'checkout')}
                              disabled={!!actionLoading}
                              className="text-xs px-2 py-1 rounded bg-orange-600 text-white hover:bg-orange-700 disabled:opacity-50"
                            >
                              {busy('checkout') ? '…' : 'Check Out'}
                            </button>
                          )}
                          {(r.status === 'PENDING' || r.status === 'CONFIRMED') && (
                            <button
                              onClick={() => doAction(r.id, 'cancel')}
                              disabled={!!actionLoading}
                              className="text-xs px-2 py-1 rounded bg-red-100 text-red-700 hover:bg-red-200 disabled:opacity-50"
                            >
                              {busy('cancel') ? '…' : 'Cancel'}
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })}
                {reservations?.length === 0 && (
                  <tr><td colSpan={7} className="px-4 py-6 text-center text-gray-400">No reservations yet.</td></tr>
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
