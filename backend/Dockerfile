# Install the intentionally small runtime dependency set separately from the
# compiler, linter, and test toolchain used by the builder.
FROM node:26-alpine AS production-deps

WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev --ignore-scripts \
  && npm cache clean --force

# Build and generate the platform-specific Prisma client.
FROM node:26-alpine AS builder

WORKDIR /app
RUN apk add --no-cache openssl
COPY package*.json ./
RUN npm ci
COPY . .
RUN npx prisma generate
RUN npm run build

# Prisma and ts-node are deliberate runtime dependencies because deployment
# runs `docker compose run --rm api npx prisma migrate deploy` and can execute
# the existing TypeScript seed. All other development tooling stays behind.
FROM node:26-alpine AS runtime

ENV NODE_ENV=production
WORKDIR /app

RUN apk add --no-cache dumb-init openssl \
  && mkdir -p /app/uploads \
  && chown node:node /app/uploads

COPY --from=production-deps --chown=node:node /app/node_modules ./node_modules
COPY --from=builder --chown=node:node /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder --chown=node:node /app/package*.json ./
COPY --from=builder --chown=node:node /app/dist ./dist
COPY --from=builder --chown=node:node /app/prisma ./prisma
# The explicit deployment seed imports canonical TypeScript seed data from
# `src`; include those sources and their compiler settings without copying any
# test, lint, or build executables into the image.
COPY --from=builder --chown=node:node /app/src ./src
# The guarded release workflow executes the catalog verifier from this
# directory before replacing the running services.
COPY --from=builder --chown=node:node /app/scripts ./scripts
COPY --from=builder --chown=node:node /app/tsconfig.json ./tsconfig.json

USER node
EXPOSE 3000

# Migrations remain an explicit release step after backup and before replacing
# the API. dumb-init forwards SIGTERM so Nest shutdown hooks can drain cleanly.
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/main.js"]
