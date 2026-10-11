# Stage 1: build the Next.js standalone bundle
FROM node:25-alpine AS builder
WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .

# NEXT_PUBLIC_* vars are inlined into the client bundle at build time, so the
# production API host must be supplied here (see docker-compose build args).
ARG NEXT_PUBLIC_KPB_API_BASE_URL
ENV NEXT_PUBLIC_KPB_API_BASE_URL=$NEXT_PUBLIC_KPB_API_BASE_URL
# Vide = rapport d'erreurs désactivé (lib/error-reporting.ts). Jamais passé au
# build jusqu'ici : Sentry restait muet en production même configuré.
ARG NEXT_PUBLIC_SENTRY_DSN=
ENV NEXT_PUBLIC_SENTRY_DSN=$NEXT_PUBLIC_SENTRY_DSN
RUN npm run build

# Stage 2: minimal runtime (Next standalone server)
FROM node:25-alpine
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

# Standalone output ships server.js + a pruned node_modules; static assets and
# public files are copied alongside it.
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

USER node
EXPOSE 3000
CMD ["node", "server.js"]
