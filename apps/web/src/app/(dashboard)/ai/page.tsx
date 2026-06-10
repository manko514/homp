'use client';

import { useState, useRef, useEffect } from 'react';
import { API_URL } from '@/lib/config';

interface Message {
  role: 'user' | 'assistant';
  content: string;
}

export default function AiAssistantPage() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');
  const [streaming, setStreaming] = useState(false);
  const [usage, setUsage] = useState<any>(null);
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  useEffect(() => {
    loadUsage();
  }, []);

  async function loadUsage() {
    const token = localStorage.getItem('homp_token');
    if (!token) return;
    try {
      const res = await fetch(`${API_URL}/ai/usage?days=7`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.ok) setUsage(await res.json());
    } catch {}
  }

  async function sendMessage() {
    if (!input.trim() || streaming) return;
    const userMsg: Message = { role: 'user', content: input.trim() };
    const newMessages = [...messages, userMsg];
    setMessages(newMessages);
    setInput('');
    setStreaming(true);

    // Add empty assistant message to stream into
    setMessages([...newMessages, { role: 'assistant', content: '' }]);

    try {
      const token = localStorage.getItem('homp_token');
      const user = JSON.parse(localStorage.getItem('homp_user') ?? '{}');
      const res = await fetch(`${API_URL}/ai/chat`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({ messages: newMessages, tenantId: user.tenantId }),
      });

      if (!res.body) throw new Error('No response body');
      const reader = res.body.getReader();
      const decoder = new TextDecoder();
      let buffer = '';

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop() ?? '';

        for (const line of lines) {
          if (!line.startsWith('data: ')) continue;
          try {
            const event = JSON.parse(line.slice(6));
            if (event.type === 'text') {
              setMessages((prev) => {
                const updated = [...prev];
                updated[updated.length - 1] = {
                  ...updated[updated.length - 1],
                  content: updated[updated.length - 1].content + event.text,
                };
                return updated;
              });
            }
            if (event.type === 'done') {
              loadUsage(); // refresh usage stats
            }
            if (event.type === 'error') {
              setMessages((prev) => {
                const updated = [...prev];
                updated[updated.length - 1] = {
                  role: 'assistant',
                  content: `⚠️ AI error: ${event.message}`,
                };
                return updated;
              });
            }
          } catch {}
        }
      }
    } catch (err) {
      setMessages((prev) => {
        const updated = [...prev];
        updated[updated.length - 1] = {
          role: 'assistant',
          content: '⚠️ Error connecting to AI. Please try again.',
        };
        return updated;
      });
    } finally {
      setStreaming(false);
    }
  }

  return (
    <div className="flex h-[calc(100vh-4rem)] gap-4 p-4">
      {/* Chat Panel */}
      <div className="flex-1 flex flex-col bg-white rounded-xl shadow border">
        {/* Header */}
        <div className="px-4 py-3 border-b flex items-center gap-3">
          <span className="text-2xl">🤖</span>
          <div>
            <h1 className="font-bold text-gray-800">AI Assistant</h1>
            <p className="text-xs text-gray-500">Powered by Claude — hotel context aware</p>
          </div>
          {streaming && (
            <span className="ml-auto text-xs text-blue-500 animate-pulse">● Thinking...</span>
          )}
        </div>

        {/* Messages */}
        <div className="flex-1 overflow-y-auto p-4 space-y-4">
          {messages.length === 0 && (
            <div className="text-center text-gray-400 mt-16">
              <div className="text-4xl mb-3">💬</div>
              <p className="font-medium">Ask me anything about the hotel</p>
              <div className="mt-4 flex flex-wrap justify-center gap-2">
                {[
                  'What rooms are available tonight?',
                  'Show me today\'s menu',
                  'How many orders are pending?',
                  'Summarize today\'s revenue',
                ].map((s) => (
                  <button
                    key={s}
                    onClick={() => setInput(s)}
                    className="text-sm px-3 py-1.5 bg-blue-50 text-blue-600 rounded-full hover:bg-blue-100"
                  >
                    {s}
                  </button>
                ))}
              </div>
            </div>
          )}

          {messages.map((msg, i) => (
            <div key={i} className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}>
              <div
                className={`max-w-[80%] rounded-2xl px-4 py-2.5 text-sm whitespace-pre-wrap ${
                  msg.role === 'user'
                    ? 'bg-blue-600 text-white rounded-br-sm'
                    : 'bg-gray-100 text-gray-800 rounded-bl-sm'
                }`}
              >
                {msg.content}
                {msg.role === 'assistant' && streaming && i === messages.length - 1 && (
                  <span className="inline-block w-1.5 h-4 bg-gray-400 animate-pulse ml-0.5 align-middle" />
                )}
              </div>
            </div>
          ))}
          <div ref={bottomRef} />
        </div>

        {/* Input */}
        <div className="p-4 border-t flex gap-2">
          <input
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && !e.shiftKey && sendMessage()}
            placeholder="Ask the AI assistant..."
            disabled={streaming}
            className="flex-1 border rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:bg-gray-50"
          />
          <button
            onClick={sendMessage}
            disabled={streaming || !input.trim()}
            className="px-4 py-2.5 bg-blue-600 text-white rounded-xl text-sm font-medium hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {streaming ? '...' : 'Send'}
          </button>
        </div>
      </div>

      {/* Usage Stats Panel */}
      <div className="w-64 space-y-4">
        <div className="bg-white rounded-xl shadow border p-4">
          <h2 className="font-bold text-sm text-gray-700 mb-3">📊 Usage (7 days)</h2>
          {usage ? (
            <div className="space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-gray-500">Requests</span>
                <span className="font-medium">{usage.totalRequests}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-500">Input tokens</span>
                <span className="font-medium">{(usage.totalInputTokens ?? 0).toLocaleString()}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-500">Output tokens</span>
                <span className="font-medium">{(usage.totalOutputTokens ?? 0).toLocaleString()}</span>
              </div>
              <div className="flex justify-between border-t pt-2 mt-2">
                <span className="text-gray-500">Total cost</span>
                <span className="font-bold text-green-600">${usage.totalCostUsd}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-500">Avg latency</span>
                <span className="font-medium">{usage.avgDurationMs}ms</span>
              </div>
            </div>
          ) : (
            <p className="text-xs text-gray-400">No usage data yet</p>
          )}
        </div>

        <div className="bg-blue-50 rounded-xl border border-blue-100 p-4 text-xs text-blue-700">
          <p className="font-semibold mb-1">🔒 Secure</p>
          <p>Your API key lives only on the server. It is never sent to the browser.</p>
        </div>
      </div>
    </div>
  );
}
