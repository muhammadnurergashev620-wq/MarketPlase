# ---------- Base ----------
FROM node:24-slim AS base
ENV PNPM_HOME=/pnpm
ENV PATH=$PNPM_HOME:$PATH
RUN corepack enable && corepack prepare pnpm@11 --activate
WORKDIR /app

# ---------- Build ----------
FROM base AS build
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --frozen-lockfile
COPY . .
RUN pnpm exec prisma generate && pnpm build

# ---------- Production dependencies ----------
FROM base AS prod-deps
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --frozen-lockfile --prod

# ---------- Runtime ----------
FROM node:24-slim AS runtime
ENV NODE_ENV=production
WORKDIR /app

COPY --chown=node:node package.json ./
COPY --chown=node:node --from=prod-deps /app/node_modules ./node_modules
COPY --chown=node:node --from=build /app/dist ./dist
# Needed for `prisma migrate deploy` inside the container
COPY --chown=node:node prisma ./prisma
COPY --chown=node:node prisma.config.ts ./
COPY --chown=node:node src/config/index.ts ./src/config/index.ts

RUN mkdir -p uploads && chown node:node uploads
USER node

EXPOSE 3000
CMD ["node", "dist/src/main.js"]
