defmodule EmailRouter do
  use Plug.Router

  # Request ID for correlation across services (BEFORE :match)
  plug(Plug.RequestId)

  # Logger with request_id metadata (BEFORE :match)
  plug(Plug.Logger, log: :info)

  # Telemetry for metrics (BEFORE :match)
  plug(Plug.Telemetry, event_prefix: [:email_svc, :plug])

  # Extract OpenTelemetry trace context from incoming requests
  plug(EmailSvc.OpenTelemetryPlug)

  plug(:match)

  plug(Plug.Parsers,
    parsers: [:json],
    json_decoder: Jason,
    # Skip parsing protobuf, let us handle it manually
    pass: ["application/protobuf"]
  )

  plug(:dispatch)

  # RPC-style protobuf endpoints (matches services.proto)

  # EmailService.SendEmail - Send email via SMTP
  post "/email_svc/SendEmail" do
    DeliveryController.send(conn)
  end

  # Health check endpoints
  match "/health", via: [:get, :head] do
    # Simple liveness check
    send_resp(conn, 200, "OK")
  end

  get "/health/ready" do
    # Readiness check - verify dependencies
    # TODO: Check MinIO, user_svc connectivity
    send_resp(conn, 200, "READY")
  end

  # Prometheus metrics endpoint
  get "/metrics" do
    metrics = TelemetryMetricsPrometheus.Core.scrape(:email_svc_metrics)

    conn
    |> put_resp_content_type("text/plain; version=0.0.4")
    |> send_resp(200, metrics)
  end
end
