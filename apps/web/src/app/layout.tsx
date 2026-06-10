import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'HOMP — Hospitality Operations Management Platform',
  description: 'Unified hotel, restaurant, bar, and HR management',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="antialiased font-sans">{children}</body>
    </html>
  );
}
