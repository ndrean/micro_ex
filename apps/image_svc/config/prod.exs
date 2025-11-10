import Config

# Production configuration for image_svc
# Most runtime config is in runtime.exs (using environment variables)

# Compile-time Phoenix endpoint configuration
config :image_svc, ImageSvcWeb.Endpoint,
  code_reloader: false
