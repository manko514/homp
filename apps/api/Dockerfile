# ─── Stage 1: builder ─────────────────────────────────────────────────────────
FROM node:20-alpine AS builder
WORKDIR /app

# Install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

# Copy workspace manifests first for layer-cache efficiency
COPY pnpm-workspace.yaml pnpm-lock.yaml package.json ./
COPY apps/api/package.json ./apps/api/

# Install all deps (including devDeps needed for build)
RUN pnpm install --frozen-lockfile --filter=api...

# Copy source and build
COPY apps/api ./apps/api
RUN pnpm --filter=api run build

# Generate Prisma client for production target
COPY apps/api/prisma ./apps/api/prisma
RUN pnpm --filter=api exec prisma generate

# ─── Stage 2: production image ────────────────────────────────────────────────
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production

RUN corepack enable && corepack prepare pnpm@latest --activate

# Copy workspace manifests
COPY pnpm-workspace.yaml pnpm-lock.yaml package.json ./
COPY apps/api/package.json ./apps/api/

# Install production deps only
RUN pnpm install --frozen-lockfile --filter=api... --prod

# Copy compiled output and Prisma artifacts from builder
COPY --from=builder /app/apps/api/dist ./apps/api/dist
COPY --from=builder /app/apps/api/prisma ./apps/api/prisma
COPY --from=builder /app/node_modules/.pnpm ./node_modules/.pnpm

# Prisma needs the schema at runtime for migrations
ENV PRISMA_SCHEMA_PATH=/app/apps/api/prisma/schema.prisma

EXPOSE 3001

# Run migrations then start the server
CMD ["sh", "-c", "cd apps/api && npx prisma migrate deploy && node dist/main"]
