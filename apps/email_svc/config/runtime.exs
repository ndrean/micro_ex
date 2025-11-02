import Config

# Runtime configuration for email_svc

# HTTP Port
port = System.get_env("PORT", "8083") |> String.to_integer()

config :email_svc,
  port: port

# OpenTelemetry Configuration
config :opentelemetry,
  service_name: System.get_env("OTEL_SERVICE_NAME", "email_svc"),
  traces_exporter: :otlp

config :opentelemetry_exporter,
  otlp_protocol: :http_protobuf,
  otlp_endpoint: System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4318")

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

# Swoosh Mailer - Local adapter (no SMTP needed!)
# For production, you can switch to SMTP, SendGrid, Mailgun, etc. via env vars
adapter_module =
  case System.get_env("MAILER_ADAPTER", "local") do
    "local" -> Swoosh.Adapters.Local
    "smtp" -> Swoosh.Adapters.SMTP
    "sendgrid" -> Swoosh.Adapters.Sendgrid
    _ -> Swoosh.Adapters.Local
  end

config :email_svc, EmailService.Mailer,
  adapter: adapter_module

# SMTP config (only used if MAILER_ADAPTER=smtp)
if adapter_module == Swoosh.Adapters.SMTP do
  config :email_svc, EmailService.Mailer,
    relay: System.get_env("SMTP_RELAY", "smtp.gmail.com"),
    username: System.get_env("SMTP_USERNAME"),
    password: System.get_env("SMTP_PASSWORD"),
    port: System.get_env("SMTP_PORT", "587") |> String.to_integer(),
    tls: :always
end
