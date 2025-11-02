defmodule JobRouter do
  @moduledoc false
  use Plug.Router

  plug(:match)
  # Request ID for correlation across services
  plug(Plug.RequestId)

  # Logger with request_id metadata
  plug(Plug.Logger, log: :info)

  # Telemetry for metrics
  plug(Plug.Telemetry, event_prefix: [:job_svc, :plug])

  plug(Plug.Parsers,
    parsers: [:json],
    json_decoder: Jason,
    # Skip parsing protobuf, let us handle it manually
    pass: ["application/protobuf"]
  )

  plug(:dispatch)

  # RPC-style protobuf endpoints (matches services.proto)

  # JobService.EnqueueEmail - Enqueue email job in Oban
  post "/job_svc/EnqueueEmail" do
    EmailSenderController.enqueue(conn)
  end

  # JobService.NotifyEmailDelivery - Receive delivery status from email_svc
  post "/job_svc/NotifyEmailDelivery" do
    EmailNotificationController.notify(conn)
  end

  # JobService.ConvertImage - Enqueue image conversion job
  post "/job_svc/ConvertImage" do
    ImageController.convert(conn)
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
    metrics = TelemetryMetricsPrometheus.Core.scrape(:job_svc_metrics)

    conn
    |> put_resp_content_type("text/plain; version=0.0.4")
    |> send_resp(200, metrics)
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
