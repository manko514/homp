import { RolesGuard } from './roles.guard';
import { Reflector } from '@nestjs/core';
import { ExecutionContext } from '@nestjs/common';

const makeContext = (role: string) =>
  ({
    getHandler: () => ({}),
    getClass: () => ({}),
    switchToHttp: () => ({
      getRequest: () => ({ user: { role } }),
    }),
  }) as unknown as ExecutionContext;

describe('RolesGuard', () => {
  let guard: RolesGuard;
  let reflector: Reflector;

  beforeEach(() => {
    reflector = new Reflector();
    guard = new RolesGuard(reflector);
  });

  it('allows access when no roles required', () => {
    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(undefined);
    expect(guard.canActivate(makeContext('GUEST'))).toBe(true);
  });

  it('allows access when user has required role', () => {
    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(['MANAGER']);
    expect(guard.canActivate(makeContext('MANAGER'))).toBe(true);
  });

  it('denies access when user lacks required role', () => {
    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(['MANAGER']);
    expect(guard.canActivate(makeContext('GUEST'))).toBe(false);
  });
});
