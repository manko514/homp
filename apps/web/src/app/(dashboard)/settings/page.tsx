'use client';

import { useState, useEffect } from 'react';
import { API_URL } from '@/lib/config';

interface TenantSettings {
  id: string;
  name: string;
  subdomain: string;
  logoUrl: string | null;
  primaryColor: string | null;
}

const PRESET_COLORS = [
  { label: 'Navy',    value: '#1E2A3A' },
  { label: 'Blue',   value: '#1565C0' },
  { label: 'Green',  value: '#2E7D32' },
  { label: 'Purple', value: '#6A1B9A' },
  { label: 'Red',    value: '#C62828' },
  { label: 'Teal',   value: '#00695C' },
  { label: 'Orange', value: '#E65100' },
  { label: 'Brown',  value: '#4E342E' },
];

export default function SettingsPage() {
  const [settings, setSettings] = useState<TenantSettings | null>(null);
  const [name, setName] = useState('');
  const [color, setColor] = useState('#1E2A3A');
  const [logoUrl, setLogoUrl] = useState('');
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState('');

  const token = typeof window !== 'undefined' ? localStorage.getItem('homp_token') : '';

  useEffect(() => {
    fetch(`${API_URL}/settings`, { headers: { Authorization: `Bearer ${token}` } })
      .then((r) => r.json())
      .then((d) => {
        setSettings(d);
        setName(d.name ?? '');
        setColor(d.primaryColor ?? '#1E2A3A');
        setLogoUrl(d.logoUrl ?? '');
      });
  }, [token]);

  async function save() {
    setSaving(true); setSaved(false); setError('');
    const res = await fetch(`${API_URL}/settings`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ name, primaryColor: color, logoUrl: logoUrl || null }),
    });
    if (res.ok) {
      const d = await res.json();
      setSettings(d);
      setSaved(true);
      setTimeout(() => setSaved(false), 3000);
    } else {
      const e = await res.json();
      setError(e.message ?? 'Failed to save');
    }
    setSaving(false);
  }

  const primary = color || '#1E2A3A';

  return (
    <div className="max-w-2xl space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-xl font-bold text-gray-800">White Label Settings</h1>
        <p className="text-sm text-gray-500 mt-0.5">Customise your property branding</p>
      </div>

      {/* Live preview */}
      <div className="bg-white rounded-xl border shadow-sm overflow-hidden">
        <div className="px-5 py-4 border-b">
          <h3 className="font-semibold text-gray-700 text-sm">Live Preview</h3>
        </div>
        <div className="p-5">
          {/* Mini sidebar preview */}
          <div className="flex rounded-xl overflow-hidden shadow-md" style={{ height: 120 }}>
            <div className="w-36 flex flex-col p-3 gap-2" style={{ backgroundColor: primary }}>
              <div className="flex items-center gap-2">
                {logoUrl ? (
                  <img src={logoUrl} alt="logo" className="w-7 h-7 rounded object-cover" onError={() => {}} />
                ) : (
                  <div className="w-7 h-7 rounded flex items-center justify-center text-white text-xs font-bold"
                    style={{ backgroundColor: 'rgba(255,255,255,0.2)' }}>
                    {name.charAt(0).toUpperCase() || 'H'}
                  </div>
                )}
                <span className="text-white text-xs font-bold truncate">{name || 'Hotel Name'}</span>
              </div>
              {['Dashboard', 'Hotel', 'Restaurant'].map((item, i) => (
                <div key={item} className="flex items-center gap-1.5 px-2 py-1 rounded"
                  style={{ backgroundColor: i === 0 ? 'rgba(255,255,255,0.15)' : 'transparent' }}>
                  <div className="w-1.5 h-1.5 rounded-full bg-white opacity-60" />
                  <span className="text-xs" style={{ color: 'rgba(255,255,255,0.7)' }}>{item}</span>
                </div>
              ))}
            </div>
            <div className="flex-1 p-3 bg-gray-50">
              <div className="h-3 rounded bg-gray-200 w-24 mb-2" />
              <div className="grid grid-cols-3 gap-2">
                {[1,2,3].map((i) => (
                  <div key={i} className="h-12 rounded-lg flex items-center justify-center text-white text-xs font-bold"
                    style={{ backgroundColor: primary, opacity: 0.85 }}>
                    KPI {i}
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Form */}
      <div className="bg-white rounded-xl border shadow-sm p-5 space-y-5">
        {error && <p className="text-xs text-red-600 bg-red-50 rounded-lg px-3 py-2">{error}</p>}
        {saved && <p className="text-xs text-green-600 bg-green-50 rounded-lg px-3 py-2">✅ Settings saved successfully</p>}

        {/* Property name */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">Property Name</label>
          <input
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Grand HOMP Hotel"
            className="w-full border rounded-lg px-3 py-2.5 text-sm focus:outline-none focus:ring-2"
            style={{ '--tw-ring-color': primary } as React.CSSProperties}
          />
          <p className="text-xs text-gray-400 mt-1">Shown in the sidebar logo and PDF reports</p>
        </div>

        {/* Subdomain (read-only) */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">Subdomain</label>
          <input
            value={settings?.subdomain ?? ''}
            readOnly
            className="w-full border rounded-lg px-3 py-2.5 text-sm bg-gray-50 text-gray-400 cursor-not-allowed"
          />
          <p className="text-xs text-gray-400 mt-1">Contact support to change your subdomain</p>
        </div>

        {/* Logo URL */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">Logo URL</label>
          <input
            value={logoUrl}
            onChange={(e) => setLogoUrl(e.target.value)}
            placeholder="https://yourdomain.com/logo.png"
            className="w-full border rounded-lg px-3 py-2.5 text-sm"
          />
          <p className="text-xs text-gray-400 mt-1">Direct URL to your logo image (PNG/SVG recommended)</p>
        </div>

        {/* Primary colour */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">Primary Colour</label>
          <div className="flex flex-wrap gap-2 mb-3">
            {PRESET_COLORS.map((c) => (
              <button
                key={c.value}
                onClick={() => setColor(c.value)}
                title={c.label}
                className="w-8 h-8 rounded-lg border-2 transition-transform hover:scale-110"
                style={{
                  backgroundColor: c.value,
                  borderColor: color === c.value ? '#fff' : 'transparent',
                  boxShadow: color === c.value ? `0 0 0 2px ${c.value}` : 'none',
                }}
              />
            ))}
            {/* Custom */}
            <div className="flex items-center gap-2 ml-2">
              <input
                type="color"
                value={color}
                onChange={(e) => setColor(e.target.value)}
                className="w-8 h-8 rounded cursor-pointer border"
                title="Custom colour"
              />
              <span className="text-xs text-gray-500 font-mono">{color}</span>
            </div>
          </div>
          <p className="text-xs text-gray-400">Used in sidebar, buttons, and report headers</p>
        </div>

        <button
          onClick={save}
          disabled={saving}
          className="w-full py-2.5 rounded-lg text-white font-medium text-sm disabled:opacity-60 transition-opacity"
          style={{ backgroundColor: primary }}
        >
          {saving ? 'Saving…' : '💾 Save Branding'}
        </button>
      </div>

      {/* Account info */}
      <div className="bg-white rounded-xl border shadow-sm p-5">
        <h3 className="font-semibold text-gray-700 text-sm mb-3">Account Info</h3>
        <div className="space-y-2 text-xs text-gray-500">
          <div className="flex justify-between">
            <span>Tenant ID</span>
            <span className="font-mono text-gray-700">{settings?.id?.slice(0, 12)}…</span>
          </div>
          <div className="flex justify-between">
            <span>Subdomain</span>
            <span className="font-medium text-gray-700">{settings?.subdomain}.homp.app</span>
          </div>
          <div className="flex justify-between">
            <span>Plan</span>
            <span className="font-medium" style={{ color: primary }}>Enterprise</span>
          </div>
        </div>
      </div>
    </div>
  );
}
