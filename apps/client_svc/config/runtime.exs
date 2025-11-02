import Config

config :opentelemetry, :processors,
  otel_batch_processor: %{
    exporter: {:opentelemetry_exporter, %{endpoints: [{:http, "localhost", 4318, []}]}}
  }

# config :opentelemetry,
#   # span_processor: :batch,
#   exporter: :otlp

config :opentelemetry_exporter,
  otlp_protocol: :http_protobuf,
  otlp_traces_endpoint: "http://localhost:4318"

config :opentelemetry, :resource, service: %{name: "client service"}
