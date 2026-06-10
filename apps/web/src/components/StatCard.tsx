interface StatCardProps {
  label: string;
  value: string | number;
  sub?: string;
  accent?: 'normal' | 'warn' | 'danger';
}

const accentColor = {
  normal: 'text-brand-700',
  warn: 'text-yellow-600',
  danger: 'text-red-600',
};

export function StatCard({ label, value, sub, accent = 'normal' }: StatCardProps) {
  return (
    <div className="bg-white rounded-lg border border-gray-200 p-5 shadow-sm">
      <p className="text-sm text-gray-500 font-medium">{label}</p>
      <p className={`text-3xl font-bold mt-1 ${accentColor[accent]}`}>{value}</p>
      {sub && <p className="text-xs text-gray-400 mt-1">{sub}</p>}
    </div>
  );
}
