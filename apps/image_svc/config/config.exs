import Config

# Configure Image Service
config :image_svc,
  port: 8084,
  user_svc_base_url: "http://localhost:8081",
  user_svc_endpoints: %{
    store_image: "/user_svc/StoreImage"
  }

# OpenTelemetry configuration for distributed tracing
config :opentelemetry,
  service_name: "image_svc",
  traces_exporter: :otlp

config :opentelemetry_exporter,
  otlp_protocol: :http_protobuf,
  otlp_endpoint: "http://localhost:4318"
