# Stage 1: Install dependencies
FROM node:20-slim AS deps

RUN corepack enable && \
    rm -f /usr/local/bin/pnpm && \
    rm -f /usr/local/bin/pnpx && \
    npm install -g pnpm

WORKDIR /app
COPY package*.json ./
COPY pnpm-lock.yaml ./
COPY .env ./

# Install dependencies
RUN pnpm install

# Stage 2: Build application
FROM node:20-slim AS build_image

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/pnpm-lock.yaml ./
COPY . .

# Install OpenSSL and build tools for bcrypt (necessary for compiling native modules)
RUN apt-get update -y && \
    apt-get install -y openssl libssl-dev build-essential python3 python3-dev && \
    npm install -g pnpm && \
    pnpm prisma generate && \
    pnpm prisma db push && \
    pnpm prisma db seed && \
    pnpm run build

# Stage 3: Production build
FROM node:20-slim AS production
ENV NODE_ENV=production

# Add system user for running the app
RUN addgroup --system nodejs && \
    adduser --system --ingroup nodejs nextjs

# Install OpenSSL and build dependencies for production environment
RUN apt-get update -y && \
    apt-get install -y openssl libssl-dev

WORKDIR /app

# Copy required files from build image
COPY --from=build_image --chown=nextjs:nodejs /app/package.json ./
COPY --from=build_image --chown=nextjs:nodejs /app/pnpm-lock.yaml ./
COPY --from=build_image --chown=nextjs:nodejs /app/node_modules ./node_modules
COPY --from=build_image --chown=nextjs:nodejs /app/public ./public
COPY --from=build_image --chown=nextjs:nodejs /app/.next ./.next
COPY --from=build_image --chown=nextjs:nodejs /app/.env ./.env

# Switch to root to install pnpm globally
USER root

# Install pnpm globally
RUN npm install -g pnpm

# Switch back to nextjs user
USER nextjs

EXPOSE 3000

# Check if pnpm is installed
RUN pnpm --version || echo "pnpm not found"

# Use npx to run pnpm
CMD [ "npx", "pnpm", "start" ]
