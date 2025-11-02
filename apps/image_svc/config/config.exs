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

# JSON structured logging with request_id correlation
config :logger, :default_handler,
  formatter:
    {LoggerJSON.Formatters.Basic,
     metadata: [
       :request_id,
       :service,
       :trace_id,
       :span_id,
       :user_id,
       :duration
     ]}

# Add service name to all logs
config :logger, :default_formatter, metadata: [:service]
