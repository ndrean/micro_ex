# Multi-stage Dockerfile for client_svc (Monorepo)
# Build context MUST be the repo root: docker build -f apps/client_svc/Dockerfile .
# Stage 1: Build the release
ARG PORT=8085
ARG OS=alpine:3.22.2
ARG ELIXIR_IMAGE=hexpm/elixir:1.19.2-erlang-28.1-alpine-3.22.2
FROM ${ELIXIR_IMAGE} AS builder

ARG PORT
ENV PORT=${PORT}

# Install build dependencies + protoc for proto compilation
RUN apk add --no-cache \
    build-base \
    git \
    openssl-dev \
    protobuf-dev \
    bash libc6-compat 

# bash libc6-compat are needed for some escripts

# Set working directory
WORKDIR /app

# Install Hex and Rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy shared protos library first (for better caching)
COPY libs/protos libs/protos/

# Copy client_svc dependency files
COPY apps/client_svc/mix.exs apps/client_svc/mix.lock apps/client_svc/
COPY apps/client_svc/config/config.exs apps/client_svc/config/prod.exs apps/client_svc/config/

# Set working directory to client_svc
WORKDIR /app/apps/client_svc

# Install dependencies (will compile protos lib automatically)
ENV MIX_ENV=prod
RUN mix deps.get --only prod

# Install protoc-gen-elixir escript (required for proto compilation)
RUN mix escript.install --force hex protobuf
ENV PATH="/root/.mix/escripts:${PATH}"

# Copy application code
COPY apps/client_svc/lib ./lib
COPY apps/client_svc/priv ./priv
COPY apps/client_svc/config/runtime.exs config/

# Compile application (protos will be compiled as dependency)
RUN mix compile

# Build release
RUN mix release

# Stage 2: Create minimal runtime image
FROM ${OS} AS app

ARG PORT
ENV PORT=${PORT}

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

# Copy release from builder (built in /app/apps/client_svc)
COPY --from=builder --chown=appuser:appuser /app/apps/client_svc/_build/prod/rel/client_svc ./

# Switch to non-root user
USER appuser

# Expose port (can be overridden with PORT env var)
EXPOSE ${PORT}

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["/bin/sh", "-c", "wget -q --spider http://localhost:${PORT}/health || exit 1"]

# Start the application
CMD ["bin/client_svc", "start"]
