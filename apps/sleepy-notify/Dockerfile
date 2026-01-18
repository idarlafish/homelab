FROM --platform=linux/arm64 oven/bun:1.2.19 AS base

# Frontend build stage
FROM base AS frontend
WORKDIR /app/frontend
COPY frontend/package.json frontend/bun.lockb* ./
RUN bun install --frozen-lockfile
COPY frontend ./
RUN bun run build

# Backend build stage with compilation
FROM base AS backend-build
WORKDIR /app/backend
COPY backend/package.json backend/bun.lockb* ./
RUN bun install --frozen-lockfile
COPY backend/src ./src
COPY --from=frontend /app/frontend/build ./public

ENV NODE_ENV=production

RUN bun build \
    --compile \
    --target bun-linux-arm64 \
    --minify-whitespace \
    --minify-syntax \
    --outfile server \
    src/index.ts

# Final image - ARM64 + glibc loader
FROM --platform=linux/arm64 gcr.io/distroless/base-debian13:nonroot
# FROM --platform=linux/arm64 debian:bookworm-slim
# RUN apt-get update && apt-get install -y libc6 ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=backend-build /app/backend/server ./server
COPY --from=backend-build /app/backend/public ./public

ENV NODE_ENV=production
EXPOSE 3000

CMD ["./server"]
