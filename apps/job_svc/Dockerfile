# Multi-stage Dockerfile for job_svc (Monorepo)
# Build context MUST be the repo root: docker build -f apps/job_svc/Dockerfile .
# Stage 1: Build the release
ARG PORT=8082
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
    protobuf-dev

# Set working directory
WORKDIR /app

# Install Hex and Rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy shared protos library first (for better caching)
COPY libs/protos libs/protos/

# Copy job_svc dependency files
COPY apps/job_svc/mix.exs apps/job_svc/mix.lock apps/job_svc/
COPY apps/job_svc/config/config.exs apps/job_svc/config/prod.exs apps/job_svc/config/

# Set working directory to job_svc
WORKDIR /app/apps/job_svc

# Install dependencies (will compile protos lib automatically)
ENV MIX_ENV=prod
RUN mix deps.get --only prod

# Install protoc-gen-elixir escript (required for proto compilation)
RUN mix escript.install --force hex protobuf
ENV PATH="/root/.mix/escripts:${PATH}"

# Copy application code
COPY apps/job_svc/lib ./lib
COPY apps/job_svc/priv ./priv
COPY apps/job_svc/config/runtime.exs config/

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

# Copy release from builder (built in /app/apps/job_svc)
COPY --from=builder --chown=appuser:appuser /app/apps/job_svc/_build/prod/rel/job_svc ./

# Create database directory with proper permissions
RUN mkdir -p /app/db && chown -R appuser:appuser /app/db

# Switch to non-root user
USER appuser

# Expose port (can be overridden with PORT env var)
EXPOSE ${PORT}

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["/bin/sh", "-c", "wget -q --spider http://localhost:${PORT}/health || exit 1"]

# Start the application
CMD ["bin/job_svc", "start"]
