'use client';

import { useState, useEffect } from 'react';
import { API_URL } from '@/lib/config';

interface PayrollItem {
  id: string;
  employeeId: string;
  basic: number;
  overtime: number;
  deductions: number;
  net: number;
  txId: string | null;
  employee: { user: { name: string; email: string; role: string } };
}

interface PayrollRun {
  id: string;
  periodStart: string;
  periodEnd: string;
  status: 'DRAFT' | 'PENDING_APPROVAL' | 'APPROVED' | 'DISBURSED';
  disbursedAt: string | null;
  createdAt: string;
  payrollItems: PayrollItem[];
  _count?: { payrollItems: number };
}

const STATUS_STYLE: Record<string, { bg: string; text: string; label: string }> = {
  DRAFT:            { bg: '#F5F6FA', text: '#64748b', label: '📝 Draft' },
  PENDING_APPROVAL: { bg: '#FFF8E1', text: '#F9A825', label: '⏳ Pending Approval' },
  APPROVED:         { bg: '#E8F5E9', text: '#2E7D32', label: '✅ Approved' },
  DISBURSED:        { bg: '#E3F2FD', text: '#1565C0', label: '💸 Disbursed' },
};

export default function PayrollPage() {
  const [runs, setRuns] = useState<PayrollRun[]>([]);
  const [selectedRun, setSelectedRun] = useState<PayrollRun | null>(null);
  const [loading, setLoading] = useState(true);
  const [creating, setCreating] = useState(false);
  const [error, setError] = useState('');
  const [showCreate, setShowCreate] = useState(false);
  const [periodStart, setPeriodStart] = useState('');
  const [periodEnd, setPeriodEnd] = useState('');

  const token = typeof window !== 'undefined' ? localStorage.getItem('homp_token') : '';

  useEffect(() => { loadRuns(); }, []);

  async function loadRuns() {
    setLoading(true);
    try {
      const res = await fetch(`${API_URL}/payroll/runs`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.ok) setRuns(await res.json());
    } catch { setError('Could not load payroll runs'); }
    finally { setLoading(false); }
  }

  async function loadRun(id: string) {
    const res = await fetch(`${API_URL}/payroll/runs/${id}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (res.ok) setSelectedRun(await res.json());
  }

  async function createRun() {
    if (!periodStart || !periodEnd) return;
    setCreating(true); setError('');
    try {
      const res = await fetch(`${API_URL}/payroll/runs`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ periodStart, periodEnd }),
      });
      if (res.ok) {
        const run = await res.json();
        setShowCreate(false);
        await loadRuns();
        setSelectedRun(run);
      } else {
        const e = await res.json();
        setError(e.message ?? 'Failed to create run');
      }
    } catch { setError('Network error'); }
    finally { setCreating(false); }
  }

  async function action(runId: string, endpoint: string) {
    setError('');
    const res = await fetch(`${API_URL}/payroll/runs/${runId}/${endpoint}`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${token}` },
    });
    if (res.ok) { await loadRuns(); if (selectedRun?.id === runId) await loadRun(runId); }
    else { const e = await res.json(); setError(e.message ?? 'Action failed'); }
  }

  async function downloadPayslip(runId: string, employeeId: string, employeeName: string) {
    const res = await fetch(`${API_URL}/payroll/runs/${runId}/payslip/${employeeId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!res.ok) return;
    const blob = await res.blob();
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = `payslip-${employeeName.replace(/\s+/g, '-')}.pdf`;
    a.click();
  }

  const totalNet = (run: PayrollRun) =>
    run.payrollItems?.reduce((s, i) => s + Number(i.net), 0) ?? 0;

  return (
    <div className="flex gap-5 h-[calc(100vh-5rem)]">
      {/* Left: run list */}
      <div className="w-72 flex flex-col gap-3 overflow-y-auto flex-shrink-0">
        <div className="flex items-center justify-between">
          <h2 className="font-bold text-gray-800">Payroll Runs</h2>
          <button
            onClick={() => setShowCreate(true)}
            className="text-xs px-3 py-1.5 rounded-lg text-white font-medium"
            style={{ backgroundColor: '#1E2A3A' }}
          >
            + New Run
          </button>
        </div>

        {error && <p className="text-xs text-red-600 bg-red-50 rounded-lg px-3 py-2">{error}</p>}

        {showCreate && (
          <div className="bg-white rounded-xl border shadow p-4 space-y-3">
            <p className="font-semibold text-sm text-gray-700">New Payroll Run</p>
            <div>
              <label className="text-xs text-gray-500">Period Start</label>
              <input type="date" value={periodStart} onChange={(e) => setPeriodStart(e.target.value)}
                className="w-full mt-1 border rounded-lg px-3 py-1.5 text-sm" />
            </div>
            <div>
              <label className="text-xs text-gray-500">Period End</label>
              <input type="date" value={periodEnd} onChange={(e) => setPeriodEnd(e.target.value)}
                className="w-full mt-1 border rounded-lg px-3 py-1.5 text-sm" />
            </div>
            <div className="flex gap-2">
              <button onClick={createRun} disabled={creating}
                className="flex-1 py-2 rounded-lg text-white text-sm font-medium disabled:opacity-60"
                style={{ backgroundColor: '#4CAF50' }}>
                {creating ? 'Creating…' : 'Create & Calculate'}
              </button>
              <button onClick={() => setShowCreate(false)}
                className="px-3 py-2 rounded-lg border text-sm text-gray-500">✕</button>
            </div>
          </div>
        )}

        {loading ? <p className="text-sm text-gray-400">Loading…</p> : runs.map((run) => {
          const style = STATUS_STYLE[run.status] ?? STATUS_STYLE.DRAFT;
          const isSelected = selectedRun?.id === run.id;
          return (
            <button key={run.id} onClick={() => loadRun(run.id)}
              className="w-full text-left p-4 rounded-xl border shadow-sm transition-all"
              style={{ backgroundColor: isSelected ? '#1E2A3A' : 'white', borderColor: isSelected ? '#1E2A3A' : '#e5e7eb' }}>
              <div className="flex items-center justify-between mb-1">
                <p className="text-xs font-semibold" style={{ color: isSelected ? '#aaa' : '#64748b' }}>
                  {new Date(run.periodStart).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })} –{' '}
                  {new Date(run.periodEnd).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}
                </p>
              </div>
              <span className="text-xs px-2 py-0.5 rounded-full" style={{ backgroundColor: style.bg, color: style.text }}>
                {style.label}
              </span>
              <p className="mt-2 text-sm font-bold" style={{ color: isSelected ? '#fff' : '#1E2A3A' }}>
                GHS {totalNet(run).toFixed(2)}
              </p>
              <p className="text-xs" style={{ color: isSelected ? '#aaa' : '#94a3b8' }}>
                {run._count?.payrollItems ?? run.payrollItems?.length ?? 0} employees
              </p>
            </button>
          );
        })}
      </div>

      {/* Right: run detail */}
      <div className="flex-1 overflow-y-auto">
        {!selectedRun ? (
          <div className="h-full flex items-center justify-center text-gray-400">
            <div className="text-center">
              <div className="text-5xl mb-3">💼</div>
              <p className="font-medium">Select a payroll run</p>
              <p className="text-sm mt-1">or create a new one to get started</p>
            </div>
          </div>
        ) : (
          <div className="space-y-5">
            {/* Run header */}
            <div className="bg-white rounded-xl border shadow p-5">
              <div className="flex items-start justify-between">
                <div>
                  <h2 className="font-bold text-gray-800 text-lg">
                    {new Date(selectedRun.periodStart).toLocaleDateString('en-US', { month: 'long', day: 'numeric' })} –{' '}
                    {new Date(selectedRun.periodEnd).toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })}
                  </h2>
                  <span className="text-xs px-2 py-1 rounded-full mt-1 inline-block"
                    style={{ backgroundColor: STATUS_STYLE[selectedRun.status]?.bg, color: STATUS_STYLE[selectedRun.status]?.text }}>
                    {STATUS_STYLE[selectedRun.status]?.label}
                  </span>
                </div>
                {/* Action buttons */}
                <div className="flex gap-2">
                  {selectedRun.status === 'DRAFT' && (
                    <button onClick={() => action(selectedRun.id, 'submit')}
                      className="px-4 py-2 rounded-lg text-sm text-white font-medium"
                      style={{ backgroundColor: '#FF9800' }}>
                      Submit for Approval
                    </button>
                  )}
                  {selectedRun.status === 'PENDING_APPROVAL' && (
                    <button onClick={() => action(selectedRun.id, 'approve')}
                      className="px-4 py-2 rounded-lg text-sm text-white font-medium"
                      style={{ backgroundColor: '#4CAF50' }}>
                      ✓ Approve
                    </button>
                  )}
                  {selectedRun.status === 'APPROVED' && (
                    <button onClick={() => action(selectedRun.id, 'disburse')}
                      className="px-4 py-2 rounded-lg text-sm text-white font-medium"
                      style={{ backgroundColor: '#2196F3' }}>
                      💸 Disburse via MoMo
                    </button>
                  )}
                </div>
              </div>

              {/* Summary row */}
              <div className="grid grid-cols-4 gap-4 mt-5">
                {[
                  { label: 'Employees', value: selectedRun.payrollItems.length.toString() },
                  { label: 'Total Basic', value: `GHS ${selectedRun.payrollItems.reduce((s, i) => s + Number(i.basic), 0).toFixed(2)}` },
                  { label: 'Total Deductions', value: `GHS ${selectedRun.payrollItems.reduce((s, i) => s + Number(i.deductions), 0).toFixed(2)}` },
                  { label: 'Total Net Pay', value: `GHS ${totalNet(selectedRun).toFixed(2)}`, highlight: true },
                ].map((stat) => (
                  <div key={stat.label} className="rounded-lg p-3"
                    style={{ backgroundColor: stat.highlight ? '#1E2A3A' : '#F5F6FA' }}>
                    <p className="text-xs" style={{ color: stat.highlight ? '#aaa' : '#64748b' }}>{stat.label}</p>
                    <p className="font-bold text-sm mt-0.5" style={{ color: stat.highlight ? '#fff' : '#1E2A3A' }}>{stat.value}</p>
                  </div>
                ))}
              </div>
            </div>

            {/* Employee payslips table */}
            <div className="bg-white rounded-xl border shadow overflow-hidden">
              <div className="px-5 py-4 border-b">
                <h3 className="font-semibold text-gray-700">Employee Payslips</h3>
              </div>
              <table className="w-full text-sm">
                <thead>
                  <tr className="bg-gray-50 text-left">
                    <th className="px-4 py-3 font-medium text-gray-500">Employee</th>
                    <th className="px-4 py-3 font-medium text-gray-500 text-right">Basic</th>
                    <th className="px-4 py-3 font-medium text-gray-500 text-right">OT</th>
                    <th className="px-4 py-3 font-medium text-gray-500 text-right">Deductions</th>
                    <th className="px-4 py-3 font-medium text-gray-500 text-right">Net Pay</th>
                    <th className="px-4 py-3 font-medium text-gray-500">MoMo Ref</th>
                    <th className="px-4 py-3 font-medium text-gray-500">Payslip</th>
                  </tr>
                </thead>
                <tbody className="divide-y">
                  {selectedRun.payrollItems.map((item) => (
                    <tr key={item.id} className="hover:bg-gray-50">
                      <td className="px-4 py-3">
                        <p className="font-medium text-gray-800">{item.employee.user.name}</p>
                        <p className="text-xs text-gray-400">{item.employee.user.role}</p>
                      </td>
                      <td className="px-4 py-3 text-right text-gray-600">GHS {Number(item.basic).toFixed(2)}</td>
                      <td className="px-4 py-3 text-right text-gray-600">GHS {Number(item.overtime).toFixed(2)}</td>
                      <td className="px-4 py-3 text-right text-red-500">-GHS {Number(item.deductions).toFixed(2)}</td>
                      <td className="px-4 py-3 text-right font-bold text-gray-800">GHS {Number(item.net).toFixed(2)}</td>
                      <td className="px-4 py-3 text-xs text-gray-400 font-mono">{item.txId ?? '—'}</td>
                      <td className="px-4 py-3">
                        <button onClick={() => downloadPayslip(selectedRun.id, item.employeeId, item.employee.user.name)}
                          className="text-xs px-3 py-1.5 rounded-lg border border-gray-200 text-gray-600 hover:bg-gray-50 flex items-center gap-1">
                          📄 PDF
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
