'use client';

import { useState, useEffect } from 'react';
import { API_URL } from '@/lib/config';

interface Alert {
  id: string;
  shiftDate: string;
  severity: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
  category: string;
  title: string;
  description: string;
  resolved: boolean;
  createdAt: string;
}

interface Stats {
  openAlerts: number;
  bySeverity: { severity: string; _count: number }[];
}

const SEVERITY_STYLE: Record<string, { bg: string; text: string; border: string; label: string }> = {
  CRITICAL: { bg: '#FFF5F5', text: '#C62828', border: '#FFCDD2', label: '🔴 Critical' },
  HIGH:     { bg: '#FFF8E1', text: '#E65100', border: '#FFE082', label: '🟠 High' },
  MEDIUM:   { bg: '#FFFDE7', text: '#F9A825', border: '#FFF176', label: '🟡 Medium' },
  LOW:      { bg: '#F1F8E9', text: '#33691E', border: '#DCEDC8', label: '🟢 Low' },
};

const CATEGORY_ICON: Record<string, string> = {
  bar: '🍺',
  restaurant: '🍽️',
  hotel: '🏨',
  staff: '👤',
  inventory: '📦',
};

export default function AnomalyPage() {
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [stats, setStats] = useState<Stats | null>(null);
  const [loading, setLoading] = useState(true);
  const [running, setRunning] = useState(false);
  const [showResolved, setShowResolved] = useState(false);
  const [error, setError] = useState('');
  const [result, setResult] = useState<{ riskScore: number; overallAssessment: string; alertsCreated: number } | null>(null);

  useEffect(() => {
    loadData();
  }, [showResolved]);

  async function loadData() {
    setLoading(true);
    const token = localStorage.getItem('homp_token');
    try {
      const [alertsRes, statsRes] = await Promise.all([
        fetch(`${API_URL}/anomaly/alerts?resolved=${showResolved}`, {
          headers: { Authorization: `Bearer ${token}` },
        }),
        fetch(`${API_URL}/anomaly/stats`, {
          headers: { Authorization: `Bearer ${token}` },
        }),
      ]);
      if (alertsRes.ok) setAlerts(await alertsRes.json());
      if (statsRes.ok) setStats(await statsRes.json());
    } catch {
      setError('Could not load alerts');
    } finally {
      setLoading(false);
    }
  }

  async function runAnalysis() {
    setRunning(true);
    setError('');
    setResult(null);
    const token = localStorage.getItem('homp_token');
    try {
      const res = await fetch(`${API_URL}/anomaly/analyze`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.ok) {
        const data = await res.json();
        setResult(data);
        await loadData();
      } else {
        const err = await res.json();
        setError(err.message ?? 'Analysis failed');
      }
    } catch {
      setError('Network error');
    } finally {
      setRunning(false);
    }
  }

  async function resolveAlert(id: string) {
    const token = localStorage.getItem('homp_token');
    await fetch(`${API_URL}/anomaly/alerts/${id}/resolve`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${token}` },
    });
    setAlerts((prev) => prev.filter((a) => a.id !== id));
    if (stats) setStats({ ...stats, openAlerts: Math.max(0, stats.openAlerts - 1) });
  }

  const criticalCount = stats?.bySeverity.find((s) => s.severity === 'CRITICAL')?._count ?? 0;
  const highCount = stats?.bySeverity.find((s) => s.severity === 'HIGH')?._count ?? 0;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-gray-800">Fraud & Anomaly Detection</h1>
          <p className="text-sm text-gray-500 mt-0.5">AI-powered shift analysis · auto-runs nightly at 11 PM</p>
        </div>
        <button
          onClick={runAnalysis}
          disabled={running}
          className="flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium text-white disabled:opacity-60"
          style={{ backgroundColor: '#C62828' }}
        >
          {running ? <><span className="animate-spin">⟳</span> Analysing…</> : <>🔍 Analyse Today's Shift</>}
        </button>
      </div>

      {error && (
        <div className="bg-red-50 border border-red-200 rounded-lg px-4 py-3 text-sm text-red-700">{error}</div>
      )}

      {result && (
        <div
          className="rounded-xl border px-5 py-4"
          style={{
            backgroundColor: result.riskScore >= 70 ? '#FFF5F5' : result.riskScore >= 40 ? '#FFF8E1' : '#F1F8E9',
            borderColor: result.riskScore >= 70 ? '#FFCDD2' : result.riskScore >= 40 ? '#FFE082' : '#DCEDC8',
          }}
        >
          <div className="flex items-center justify-between">
            <div>
              <p className="font-semibold text-gray-800">
                Risk Score: <span style={{ color: result.riskScore >= 70 ? '#C62828' : result.riskScore >= 40 ? '#E65100' : '#33691E' }}>{result.riskScore}/100</span>
              </p>
              <p className="text-sm text-gray-600 mt-0.5">{result.overallAssessment}</p>
            </div>
            <p className="text-sm text-gray-500">{result.alertsCreated} alert{result.alertsCreated !== 1 ? 's' : ''} created</p>
          </div>
        </div>
      )}

      {/* Stats Cards */}
      <div className="grid grid-cols-4 gap-4">
        <div className="bg-white rounded-xl border shadow p-4">
          <p className="text-xs text-gray-500 mb-1">Open Alerts</p>
          <p className="text-3xl font-bold text-gray-800">{stats?.openAlerts ?? 0}</p>
          <p className="text-xs text-gray-400 mt-1">unresolved</p>
        </div>
        <div className="bg-white rounded-xl border shadow p-4" style={{ borderLeftWidth: 3, borderLeftColor: '#C62828' }}>
          <p className="text-xs text-gray-500 mb-1">Critical</p>
          <p className="text-3xl font-bold" style={{ color: '#C62828' }}>{criticalCount}</p>
          <p className="text-xs text-gray-400 mt-1">last 30 days</p>
        </div>
        <div className="bg-white rounded-xl border shadow p-4" style={{ borderLeftWidth: 3, borderLeftColor: '#E65100' }}>
          <p className="text-xs text-gray-500 mb-1">High</p>
          <p className="text-3xl font-bold" style={{ color: '#E65100' }}>{highCount}</p>
          <p className="text-xs text-gray-400 mt-1">last 30 days</p>
        </div>
        <div className="bg-white rounded-xl border shadow p-4">
          <p className="text-xs text-gray-500 mb-1">Total (30d)</p>
          <p className="text-3xl font-bold text-gray-800">
            {stats?.bySeverity.reduce((s, x) => s + x._count, 0) ?? 0}
          </p>
          <p className="text-xs text-gray-400 mt-1">all severities</p>
        </div>
      </div>

      {/* Alert List */}
      <div className="bg-white rounded-xl border shadow">
        <div className="px-5 py-4 border-b flex items-center justify-between">
          <h2 className="font-semibold text-gray-700">
            {showResolved ? 'All Alerts' : 'Open Alerts'}
          </h2>
          <label className="flex items-center gap-2 text-sm text-gray-500 cursor-pointer">
            <input
              type="checkbox"
              checked={showResolved}
              onChange={(e) => setShowResolved(e.target.checked)}
              className="rounded"
            />
            Show resolved
          </label>
        </div>

        {loading ? (
          <div className="py-12 text-center text-gray-400">Loading…</div>
        ) : alerts.length === 0 ? (
          <div className="py-16 text-center text-gray-400">
            <div className="text-4xl mb-3">✅</div>
            <p className="font-medium text-gray-600">No alerts</p>
            <p className="text-sm mt-1">
              {showResolved ? 'No alerts recorded yet' : 'All clear — run an analysis to check today\'s shift'}
            </p>
          </div>
        ) : (
          <div className="divide-y">
            {alerts.map((alert) => {
              const style = SEVERITY_STYLE[alert.severity] ?? SEVERITY_STYLE.LOW;
              return (
                <div key={alert.id} className="px-5 py-4 flex gap-4 items-start">
                  {/* Severity badge */}
                  <div
                    className="flex-shrink-0 text-xs font-semibold px-2 py-1 rounded-full"
                    style={{ backgroundColor: style.bg, color: style.text, border: `1px solid ${style.border}` }}
                  >
                    {style.label}
                  </div>

                  {/* Content */}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      <span>{CATEGORY_ICON[alert.category] ?? '⚠️'}</span>
                      <p className="font-semibold text-gray-800 text-sm">{alert.title}</p>
                    </div>
                    <p className="text-sm text-gray-500 mt-0.5">{alert.description}</p>
                    <p className="text-xs text-gray-400 mt-1">
                      {new Date(alert.shiftDate).toLocaleDateString()} · {alert.category}
                    </p>
                  </div>

                  {/* Resolve button */}
                  {!alert.resolved && (
                    <button
                      onClick={() => resolveAlert(alert.id)}
                      className="flex-shrink-0 text-xs px-3 py-1.5 rounded-lg border border-gray-200 text-gray-500 hover:bg-gray-50"
                    >
                      Resolve
                    </button>
                  )}
                  {alert.resolved && (
                    <span className="flex-shrink-0 text-xs text-green-500 font-medium">✓ Resolved</span>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
