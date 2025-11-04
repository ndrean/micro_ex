# Multi-stage Dockerfile for client_svc
# Stage 1: Build the release
ARG ELIXIR_IMAGE=hexpm/elixir:1.19.2-erlang-28.1-alpine-3.22.2
FROM ${ELIXIR_IMAGE} AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    openssl-dev

# Set working directory
WORKDIR /app

# Install Hex and Rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy dependency files first (for better caching)
COPY mix.exs mix.lock ./
COPY config/config.exs config/

# Install dependencies
ENV MIX_ENV=prod
RUN mix deps.get --only prod

# Copy application code
COPY lib ./lib
COPY priv ./priv
COPY config/runtime.exs config/

# Compile application
RUN mix compile

# Build release
RUN mix release

# Stage 2: Create minimal runtime image
FROM alpine:3.22.2 AS app

# Install runtime dependencies
RUN apk add --no-cache \
    bash \
    openssl \
    ncurses-libs \
    libstdc++ \
    wget

# Create app user
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

WORKDIR /app

# Copy release from builder
COPY --from=builder --chown=appuser:appuser /app/_build/prod/rel/client_svc ./

# Switch to non-root user
USER appuser

# Expose port (can be overridden with PORT env var)
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["/bin/sh", "-c", "wget -q --spider http://localhost:${PORT:-4000}/health || exit 1"]

# Start the application
CMD ["bin/client_svc", "start"]
