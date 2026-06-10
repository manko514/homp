interface BadgeProps {
  label: string;
  variant?: 'green' | 'yellow' | 'red' | 'blue' | 'gray';
}

const colors: Record<NonNullable<BadgeProps['variant']>, string> = {
  green: 'bg-green-100 text-green-800',
  yellow: 'bg-yellow-100 text-yellow-800',
  red: 'bg-red-100 text-red-800',
  blue: 'bg-blue-100 text-blue-800',
  gray: 'bg-gray-100 text-gray-700',
};

export function Badge({ label, variant = 'gray' }: BadgeProps) {
  return (
    <span className={`inline-block px-2 py-0.5 rounded text-xs font-medium ${colors[variant]}`}>
      {label}
    </span>
  );
}
