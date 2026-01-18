FROM oven/bun:1.2.19 AS base

FROM base AS frontend
WORKDIR /app/frontend
COPY frontend/package.json frontend/bun.lockb* ./
RUN bun install --frozen-lockfile
COPY frontend ./
RUN bun run build

FROM base AS backend-prod
WORKDIR /app/backend
COPY backend/package.json backend/bun.lockb* ./
RUN bun install --frozen-lockfile --production
COPY backend/src ./src

FROM backend-prod AS release
COPY --from=frontend /app/frontend/build ./public
ENV NODE_ENV=production
EXPOSE 3000
ENTRYPOINT ["bun", "start"]
