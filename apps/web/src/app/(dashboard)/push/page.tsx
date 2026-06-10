'use client';

import { useState } from 'react';
import { API_URL } from '@/lib/config';

const ROLES = ['GUEST', 'WAITER', 'BARTENDER', 'HOUSEKEEPER', 'MANAGER'];

const TEMPLATES = [
  { label: 'Happy Hour',  title: 'Happy Hour Alert 🍹', body: 'Enjoy 20% off all drinks at the bar until 8PM tonight!' },
  { label: 'Pool Open',   title: 'Pool is Now Open 🏊', body: 'The pool deck is open. Come enjoy the sunshine!' },
  { label: 'Late Check-out', title: 'Late Check-out Available', body: 'Request a late check-out until 2PM at no extra charge today.' },
  { label: 'Breakfast',   title: 'Breakfast is Served 🍳', body: 'Join us at the restaurant for breakfast, served until 11AM.' },
];

export default function PushPage() {
  const [title, setTitle]       = useState('');
  const [body, setBody]         = useState('');
  const [role, setRole]         = useState('GUEST');
  const [sending, setSending]   = useState(false);
  const [result, setResult]     = useState<{ ok: boolean; message: string } | null>(null);

  const token = typeof window !== 'undefined' ? localStorage.getItem('homp_token') : '';

  async function send() {
    if (!title.trim() || !body.trim()) return;
    setSending(true);
    setResult(null);
    const res = await fetch(`${API_URL}/notifications/campaign`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ title: title.trim(), body: body.trim(), role }),
    });
    const data = await res.json();
    setResult({ ok: res.ok, message: data.message ?? (res.ok ? 'Sent!' : 'Failed to send') });
    if (res.ok) { setTitle(''); setBody(''); }
    setSending(false);
  }

  return (
    <div className="max-w-2xl space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-xl font-bold text-gray-800">Push Notifications</h1>
        <p className="text-sm text-gray-500 mt-0.5">Send a campaign to all guests or staff via FCM</p>
      </div>

      {/* Quick templates */}
      <div className="bg-white rounded-xl border shadow-sm p-5">
        <h3 className="text-sm font-semibold text-gray-700 mb-3">Quick Templates</h3>
        <div className="flex flex-wrap gap-2">
          {TEMPLATES.map((t) => (
            <button
              key={t.label}
              onClick={() => { setTitle(t.title); setBody(t.body); }}
              className="px-3 py-1.5 rounded-lg border text-xs font-medium text-gray-600 hover:bg-gray-50 transition-colors"
            >
              {t.label}
            </button>
          ))}
        </div>
      </div>

      {/* Compose form */}
      <div className="bg-white rounded-xl border shadow-sm p-5 space-y-4">
        <h3 className="text-sm font-semibold text-gray-700">Compose Message</h3>

        {result && (
          <div
            className="rounded-lg px-4 py-3 text-sm"
            style={{
              backgroundColor: result.ok ? '#E8F5E9' : '#FFEBEE',
              color: result.ok ? '#2E7D32' : '#C62828',
            }}
          >
            {result.ok ? '✅ ' : '❌ '}{result.message}
          </div>
        )}

        {/* Target audience */}
        <div>
          <label className="block text-xs font-medium text-gray-600 mb-1.5">Target Audience</label>
          <div className="flex flex-wrap gap-2">
            {ROLES.map((r) => (
              <button
                key={r}
                onClick={() => setRole(r)}
                className="px-3 py-1.5 rounded-lg text-xs font-medium transition-colors"
                style={{
                  backgroundColor: role === r ? '#1E2A3A' : '#F5F6FA',
                  color: role === r ? '#fff' : '#64748b',
                }}
              >
                {r === 'GUEST' ? '👤 All Guests' : r}
              </button>
            ))}
          </div>
        </div>

        {/* Title */}
        <div>
          <label className="block text-xs font-medium text-gray-600 mb-1.5">Notification Title</label>
          <input
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="e.g. Happy Hour Alert 🍹"
            className="w-full border rounded-lg px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-gray-300"
          />
          <p className="text-xs text-gray-400 mt-1">{title.length}/65 characters</p>
        </div>

        {/* Body */}
        <div>
          <label className="block text-xs font-medium text-gray-600 mb-1.5">Message Body</label>
          <textarea
            value={body}
            onChange={(e) => setBody(e.target.value)}
            placeholder="e.g. Enjoy 20% off all drinks at the bar until 8PM tonight!"
            rows={4}
            className="w-full border rounded-lg px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-gray-300 resize-none"
          />
          <p className="text-xs text-gray-400 mt-1">{body.length}/200 characters</p>
        </div>

        {/* Preview */}
        {(title || body) && (
          <div className="border rounded-xl p-4 bg-gray-50">
            <p className="text-xs text-gray-400 mb-2 uppercase tracking-wide font-medium">Preview</p>
            <div className="bg-white rounded-xl border shadow-sm p-3 flex gap-3 items-start">
              <div
                className="w-10 h-10 rounded-xl flex items-center justify-center text-white font-bold text-sm flex-shrink-0"
                style={{ backgroundColor: '#1E2A3A' }}
              >
                H
              </div>
              <div>
                <p className="text-sm font-semibold text-gray-800">{title || 'Notification Title'}</p>
                <p className="text-xs text-gray-500 mt-0.5 leading-relaxed">{body || 'Message body goes here…'}</p>
              </div>
            </div>
          </div>
        )}

        <button
          onClick={send}
          disabled={sending || !title.trim() || !body.trim()}
          className="w-full py-3 rounded-xl text-white font-semibold text-sm disabled:opacity-50 transition-opacity"
          style={{ backgroundColor: '#1E2A3A' }}
        >
          {sending ? 'Sending…' : `🔔 Send to All ${role === 'GUEST' ? 'Guests' : role + 's'}`}
        </button>
      </div>

      {/* Info box */}
      <div className="bg-blue-50 border border-blue-100 rounded-xl p-4 text-sm text-blue-700">
        <p className="font-semibold mb-1">How it works</p>
        <ul className="list-disc list-inside space-y-1 text-xs">
          <li>Messages are sent via Firebase Cloud Messaging (FCM) to all registered devices.</li>
          <li>Only users who have granted notification permissions will receive the message.</li>
          <li>Guests must be logged in to the HOMP app to have a registered FCM token.</li>
        </ul>
      </div>
    </div>
  );
}
