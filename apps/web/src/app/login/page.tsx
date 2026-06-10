'use client';

import { useState, FormEvent } from 'react';
import { useRouter } from 'next/navigation';
import { api, setToken } from '@/lib/api';

export default function LoginPage() {
  const router = useRouter();
  const [subdomain, setSubdomain] = useState('demo');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      // Resolve subdomain → tenantId
      const tenant = await api.get<{ id: string; name: string }>(`/auth/tenant?subdomain=${subdomain.trim().toLowerCase()}`);

      const res = await api.post<{ accessToken: string; user: object }>('/auth/login', {
        email,
        password,
        tenantId: tenant.id,
      });
      setToken(res.accessToken);
      localStorage.setItem('homp_user', JSON.stringify(res.user));
      router.push('/dashboard');
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Login failed');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center">
      <div className="bg-white rounded-xl shadow-md w-full max-w-sm p-8">
        <h1 className="text-2xl font-bold text-brand-700 mb-1">HOMP</h1>
        <p className="text-sm text-gray-500 mb-6">Hospitality Operations Management</p>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Hotel Code</label>
            <input
              type="text"
              required
              value={subdomain}
              onChange={(e) => setSubdomain(e.target.value)}
              placeholder="demo"
              className="w-full border border-gray-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-600"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
            <input
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="admin@homp.demo"
              className="w-full border border-gray-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-600"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Password</label>
            <input
              type="password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
              className="w-full border border-gray-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-600"
            />
          </div>

          {error && (
            <p className="text-sm text-red-600 bg-red-50 rounded-md px-3 py-2">{error}</p>
          )}

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-brand-700 text-white rounded-md py-2 text-sm font-medium hover:bg-brand-600 disabled:opacity-50 transition-colors"
          >
            {loading ? 'Signing in…' : 'Sign in'}
          </button>
        </form>

        <p className="text-xs text-gray-400 mt-6 text-center">
          Hotel Code: demo · admin@homp.demo / admin123
        </p>
      </div>
    </div>
  );
}
