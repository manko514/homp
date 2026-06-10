# Sprint 1A — Test Gate Checklist

## Prerequisites
- [ ] PostgreSQL running (default port 5432)
- [ ] Copy `.env.example` → `apps/api/.env` and fill in DATABASE_URL + JWT_SECRET

## Setup
```bash
cd apps/api
pnpm prisma:generate        # Generate Prisma client
pnpm prisma:migrate         # Run DB migrations (creates schema)
pnpm db:seed                # Seed demo tenant + users + rooms + menu
```

## Test: Auth Routes (all must pass)

### 1. Unauthenticated request → 401
```bash
curl http://localhost:3001/hotel/rooms
# Expected: 401 Unauthorized
```

### 2. Login with valid credentials → tokens
```bash
curl -X POST http://localhost:3001/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@homp.demo","password":"admin123","tenantId":"<tenant-id-from-seed>"}'
# Expected: { accessToken, refreshToken, user }
```

### 3. Login with wrong password → 401
```bash
curl -X POST http://localhost:3001/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@homp.demo","password":"wrong","tenantId":"<tenant-id>"}'
# Expected: 401 {"message":"Invalid credentials"}
```

### 4. Authorized request → data
```bash
curl http://localhost:3001/hotel/rooms \
  -H "Authorization: Bearer <accessToken>"
# Expected: 200 array of rooms
```

### 5. Wrong role → 403
```bash
# Login as GUEST, try to access /hotel/rooms
# Expected: 403 Forbidden
```

### 6. Token refresh
```bash
curl -X POST http://localhost:3001/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{"refreshToken":"<refreshToken>"}'
# Expected: new accessToken + refreshToken
```

## Test: Unit Tests
```bash
cd apps/api
pnpm test:cov
# Expected: >80% coverage, all tests green
```

## Sprint 1A DONE when:
- [x] All auth routes above pass manually
- [x] Unit tests pass (AuthService + RolesGuard)
- [x] pnpm install completed successfully
- [x] Prisma schema migrated without errors
- [x] Seed data loaded (5 rooms, 8 tables, 5 menu items, 5 stock items)
