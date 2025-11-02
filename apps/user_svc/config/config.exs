# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

# Configure ExAws for MinIO (S3-compatible storage)
config :ex_aws,
  access_key_id: "minioadmin",
  secret_access_key: "minioadmin",
  region: "us-east-1",
  json_codec: Jason

config :ex_aws, :s3,
  scheme: "http://",
  host: "localhost",
  port: 9000,
  region: "us-east-1"

# External service URLs
config :user_svc,
  user_svc_base_url: "http://localhost:8081",
  job_svc_base_url: "http://localhost:8082",
  client_svc_base_url: "http://localhost:4000",
  job_svc_endpoints: %{
    convert_image: "/job_svc/ConvertImage",
    enqueue_email: "/job_svc/EnqueueEmail"
  },
  client_svc_endpoints: %{
    pdf_ready: "/client_svc/PdfReady",
    receive_notification: "/client_svc/ReceiveNotification"
  }

# OpenTelemetry configuration for distributed tracing
config :opentelemetry,
  service_name: "user_svc",
  traces_exporter: :otlp

config :opentelemetry_exporter,
  otlp_protocol: :http_protobuf,
  otlp_endpoint: "http://localhost:4318"

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
