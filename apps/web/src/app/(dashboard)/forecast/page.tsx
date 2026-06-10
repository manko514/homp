'use client';

import { useState, useEffect } from 'react';
import { API_URL } from '@/lib/config';
import {
  LineChart, Line, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip,
  ResponsiveContainer, Legend,
} from 'recharts';

interface DailyForecast {
  date: string;
  revenue: number;
  orders: number;
  reservations: number;
}

interface ForecastData {
  summary?: string;
  totalForecastedRevenue?: number;
  avgDailyRevenue?: number;
  trend?: 'upward' | 'downward' | 'stable';
  confidence?: number;
  recommendations?: string[];
  dailyForecasts?: DailyForecast[];
  parseError?: string;
}

interface Forecast {
  id: string;
  forecastDate: string;
  forecastType: string;
  confidence: number;
  createdAt: string;
  dataJson: ForecastData;
}

const TREND_ICON: Record<string, string> = {
  upward: '📈',
  downward: '📉',
  stable: '➡️',
};

const TREND_COLOR: Record<string, string> = {
  upward: '#4CAF50',
  downward: '#F44336',
  stable: '#FF9800',
};

export default function ForecastPage() {
  const [forecast, setForecast] = useState<Forecast | null>(null);
  const [loading, setLoading] = useState(true);
  const [running, setRunning] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    loadForecast();
  }, []);

  async function loadForecast() {
    setLoading(true);
    const token = localStorage.getItem('homp_token');
    try {
      const res = await fetch(`${API_URL}/forecast/latest`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.ok) {
        setForecast(await res.json());
      } else {
        setForecast(null);
      }
    } catch {
      setError('Could not load forecast');
    } finally {
      setLoading(false);
    }
  }

  async function runForecast() {
    setRunning(true);
    setError('');
    const token = localStorage.getItem('homp_token');
    try {
      const res = await fetch(`${API_URL}/forecast/run`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.ok) {
        const data = await res.json();
        setForecast(data);
      } else {
        const err = await res.json();
        setError(err.message ?? 'Forecast failed');
      }
    } catch {
      setError('Network error — is the API running?');
    } finally {
      setRunning(false);
    }
  }

  const data: ForecastData = forecast?.dataJson ?? {};
  const trend = data.trend ?? 'stable';
  const confidence = Math.round((data.confidence ?? 0) * 100);

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-gray-800">AI Revenue Forecast</h1>
          <p className="text-sm text-gray-500 mt-0.5">
            30-day forward forecast · powered by Claude
            {forecast && (
              <span className="ml-2 text-xs text-gray-400">
                Last run: {new Date(forecast.createdAt).toLocaleString()}
              </span>
            )}
          </p>
        </div>
        <button
          onClick={runForecast}
          disabled={running}
          className="flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium text-white disabled:opacity-60"
          style={{ backgroundColor: '#1E2A3A' }}
        >
          {running ? (
            <>
              <span className="animate-spin">⟳</span> Generating…
            </>
          ) : (
            <>🤖 Run Forecast Now</>
          )}
        </button>
      </div>

      {error && (
        <div className="bg-red-50 border border-red-200 rounded-lg px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {loading ? (
        <div className="text-center py-20 text-gray-400">
          <div className="text-4xl mb-3">⏳</div>
          <p>Loading forecast…</p>
        </div>
      ) : !forecast ? (
        <div className="text-center py-20 text-gray-400 bg-white rounded-xl border shadow">
          <div className="text-4xl mb-3">🔮</div>
          <p className="font-medium text-gray-600">No forecast yet</p>
          <p className="text-sm mt-1">Click "Run Forecast Now" to generate your first AI forecast</p>
          <p className="text-xs mt-3 text-gray-400">Forecasts also run automatically every night at 2 AM</p>
        </div>
      ) : (
        <>
          {/* Summary Cards */}
          <div className="grid grid-cols-4 gap-4">
            <div className="bg-white rounded-xl border shadow p-4">
              <p className="text-xs text-gray-500 mb-1">30-Day Revenue</p>
              <p className="text-2xl font-bold text-gray-800">
                ${(data.totalForecastedRevenue ?? 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
              </p>
              <p className="text-xs text-gray-400 mt-1">forecasted total</p>
            </div>

            <div className="bg-white rounded-xl border shadow p-4">
              <p className="text-xs text-gray-500 mb-1">Avg Daily Revenue</p>
              <p className="text-2xl font-bold text-gray-800">
                ${(data.avgDailyRevenue ?? 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
              </p>
              <p className="text-xs text-gray-400 mt-1">per day</p>
            </div>

            <div className="bg-white rounded-xl border shadow p-4">
              <p className="text-xs text-gray-500 mb-1">Trend</p>
              <p className="text-2xl font-bold" style={{ color: TREND_COLOR[trend] }}>
                {TREND_ICON[trend]} {trend.charAt(0).toUpperCase() + trend.slice(1)}
              </p>
              <p className="text-xs text-gray-400 mt-1">revenue direction</p>
            </div>

            <div className="bg-white rounded-xl border shadow p-4">
              <p className="text-xs text-gray-500 mb-1">AI Confidence</p>
              <div className="flex items-end gap-1">
                <p className="text-2xl font-bold text-gray-800">{confidence}%</p>
              </div>
              <div className="mt-2 h-1.5 bg-gray-100 rounded-full">
                <div
                  className="h-1.5 rounded-full"
                  style={{ width: `${confidence}%`, backgroundColor: confidence >= 70 ? '#4CAF50' : '#FF9800' }}
                />
              </div>
            </div>
          </div>

          {/* Summary + Recommendations */}
          <div className="grid grid-cols-2 gap-4">
            <div className="bg-white rounded-xl border shadow p-5">
              <h2 className="font-semibold text-gray-700 mb-3">📊 AI Analysis</h2>
              <p className="text-sm text-gray-600 leading-relaxed">{data.summary ?? 'No summary available.'}</p>
            </div>

            <div className="bg-white rounded-xl border shadow p-5">
              <h2 className="font-semibold text-gray-700 mb-3">💡 Recommendations</h2>
              {data.recommendations && data.recommendations.length > 0 ? (
                <ul className="space-y-2">
                  {data.recommendations.map((r, i) => (
                    <li key={i} className="flex gap-2 text-sm text-gray-600">
                      <span className="text-green-500 flex-shrink-0">✓</span>
                      {r}
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="text-sm text-gray-400">No recommendations yet.</p>
              )}
            </div>
          </div>

          {/* Revenue Line Chart */}
          {data.dailyForecasts && data.dailyForecasts.length > 0 && (
            <>
              <div className="bg-white rounded-xl border shadow p-5">
                <h2 className="font-semibold text-gray-700 mb-4">📈 30-Day Revenue Forecast</h2>
                <ResponsiveContainer width="100%" height={260}>
                  <LineChart
                    data={data.dailyForecasts.map((d) => ({
                      date: new Date(d.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
                      revenue: Number(d.revenue.toFixed(2)),
                      orders: d.orders,
                    }))}
                    margin={{ top: 5, right: 20, left: 0, bottom: 5 }}
                  >
                    <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                    <XAxis dataKey="date" tick={{ fontSize: 11 }} interval={4} />
                    <YAxis tick={{ fontSize: 11 }} tickFormatter={(v) => `$${v}`} />
                    <Tooltip formatter={(v: number) => [`$${v.toFixed(2)}`, 'Revenue']} />
                    <Legend />
                    <Line
                      type="monotone"
                      dataKey="revenue"
                      stroke="#4CAF50"
                      strokeWidth={2}
                      dot={false}
                      activeDot={{ r: 5 }}
                    />
                  </LineChart>
                </ResponsiveContainer>
              </div>

              <div className="bg-white rounded-xl border shadow p-5">
                <h2 className="font-semibold text-gray-700 mb-4">📊 Orders & Reservations Forecast</h2>
                <ResponsiveContainer width="100%" height={220}>
                  <BarChart
                    data={data.dailyForecasts.map((d) => ({
                      date: new Date(d.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
                      orders: d.orders,
                      reservations: d.reservations,
                    }))}
                    margin={{ top: 5, right: 20, left: 0, bottom: 5 }}
                  >
                    <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                    <XAxis dataKey="date" tick={{ fontSize: 11 }} interval={4} />
                    <YAxis tick={{ fontSize: 11 }} />
                    <Tooltip />
                    <Legend />
                    <Bar dataKey="orders" fill="#2196F3" radius={[3, 3, 0, 0]} />
                    <Bar dataKey="reservations" fill="#FF9800" radius={[3, 3, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </>
          )}
        </>
      )}
    </div>
  );
}
