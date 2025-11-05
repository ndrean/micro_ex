import Config

# Runtime configuration for client_svc
# All values can be overridden via environment variables

# HTTP Port
port = System.get_env("CLIENT_SVC_PORT", "8085") |> String.to_integer()

config :client_svc,
  port: port,
  # Use USER_SVC_URL from docker-compose (http://user_svc:8081) or fallback to localhost for dev
  user_svc_base_url: System.get_env("USER_SVC_URL", "http://127.0.0.1:#{System.get_env("USER_SVC_PORT", "8081")}"),
  user_endpoints: %{
    create: "/user_svc/CreateUser",
    convert_image: "/user_svc/ConvertImage"
  }

# OpenTelemetry Configuration
config :opentelemetry,
  service_name: System.get_env("OTEL_SERVICE_NAME", "client_svc"),
  traces_exporter: :otlp

config :opentelemetry_exporter,
  otlp_protocol: :http_protobuf,
  otlp_endpoint: System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://127.0.0.1:4318")

# Logger Configuration
log_level = System.get_env("LOG_LEVEL", "info") |> String.to_atom()

config :logger,
  level: log_level

# Optionally configure JSON logging
if System.get_env("LOG_FORMAT") == "json" do
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
end
