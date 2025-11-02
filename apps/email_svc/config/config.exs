import Config
# Configure Email Service
config :email_svc,
  ecto_repos: []

# Configure Swoosh Mailer
config :email_svc, EmailService.Mailer, adapter: Swoosh.Adapters.Local

# Disable Swoosh API client (not needed for Local adapter)
config :swoosh, :api_client, false
config :swoosh, :json_library, JSON

config :opentelemetry,
  #   span_processor: :batch,
  exporter: :otlp

config :opentelemetry_exporter,
  otlp_protocol: :http_protobuf,
  otlp_traces_endpoint: "http://localhost:4318"

config :opentelemetry, :processors,
  otel_batch_processor: %{
    exporter: {:opentelemetry_exporter, %{endpoints: [{:http, "localhost", 4318, []}]}}
  }

config :opentelemetry, :resource, service: %{name: "email service"}

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
