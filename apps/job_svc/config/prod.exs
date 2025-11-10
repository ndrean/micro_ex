import Config

# Production configuration for job_svc
# Most runtime config is in runtime.exs (using environment variables)

# Compile-time Phoenix endpoint configuration
config :job_svc, JobServiceWeb.Endpoint,
  code_reloader: false
