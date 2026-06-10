'use client';

const BASE = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3001';

export function getToken(): string | null {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem('homp_token');
}

export function setToken(token: string) {
  localStorage.setItem('homp_token', token);
}

export function clearToken() {
  localStorage.removeItem('homp_token');
  localStorage.removeItem('homp_user');
}

export function getUser() {
  if (typeof window === 'undefined') return null;
  try {
    const raw = localStorage.getItem('homp_user');
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

async function request<T>(path: string, options?: RequestInit): Promise<T> {
  const token = getToken();

  const res = await fetch(`${BASE}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(options?.headers ?? {}),
    },
  });

  if (res.status === 401) {
    clearToken();
    window.location.href = '/login';
    throw new Error('Unauthorized');
  }

  if (!res.ok) {
    const err = await res.json().catch(() => ({ message: 'Request failed' }));
    throw new Error(err.message ?? 'Request failed');
  }

  // 204 No Content
  if (res.status === 204) return undefined as T;
  return res.json();
}

export const api = {
  get: <T>(path: string) => request<T>(path),
  post: <T>(path: string, body: unknown) =>
    request<T>(path, { method: 'POST', body: JSON.stringify(body) }),
  patch: <T>(path: string, body: unknown) =>
    request<T>(path, { method: 'PATCH', body: JSON.stringify(body) }),
};

// SWR fetcher — returns any so useSWR<T> generics resolve correctly
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const fetcher = (path: string): Promise<any> => api.get<any>(path);

// PDF download helper — opens in new tab after injecting token in URL
export function downloadPdf(path: string) {
  const token = getToken();
  const url = `${BASE}${path}`;
  // Fetch as blob and force download
  fetch(url, {
    headers: { Authorization: `Bearer ${token}` },
  })
    .then((r) => r.blob())
    .then((blob) => {
      const a = document.createElement('a');
      a.href = URL.createObjectURL(blob);
      a.download = path.split('/').pop()?.replace('pdf', '') + '.pdf';
      a.click();
    });
}
