// Shared types used across API and Web

export type Role =
  | 'GUEST'
  | 'RECEPTIONIST'
  | 'WAITER'
  | 'BARTENDER'
  | 'SECURITY'
  | 'HOUSEKEEPER'
  | 'HR_MANAGER'
  | 'ACCOUNTANT'
  | 'MANAGER'
  | 'DIRECTOR'
  | 'ADMIN';

export interface AuthUser {
  id: string;
  email: string;
  role: Role;
  tenantId: string;
}

export interface ApiResponse<T> {
  data: T;
  message?: string;
}

export interface PaginatedResponse<T> {
  data: T[];
  total: number;
  page: number;
  pageSize: number;
}
