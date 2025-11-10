defmodule ImageSvcWeb.Endpoint do
  @moduledoc """
  Phoenix endpoint for image_svc.

  Minimal configuration for protobuf-based microservice:
  - No sessions, no static files, no LiveView
  - Protobuf content-type support
  - PromEx metrics endpoint
  - OpenAPI documentation
  """

  use Phoenix.Endpoint, otp_app: :image_svc

  # PromEx metrics endpoint (must be BEFORE Plug.Telemetry to avoid self-instrumentation)
  plug(PromEx.Plug, prom_ex_module: ImageService.PromEx)

  # Request ID for distributed tracing correlation
  plug(Plug.RequestId)

  # Phoenix telemetry (emits events for OpenTelemetry)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  # Parse JSON, but pass protobuf through unchanged
  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["application/protobuf", "application/x-protobuf"],
    json_decoder: Jason
  )

  # OpenAPI spec generation
  plug(OpenApiSpex.Plug.PutApiSpec, module: ImageSvc.ApiSpec)

  # HEAD request support (OPTIONS/HEAD for health checks)
  plug(Plug.Head)

  # Route to controllers
  plug(ImageSvcWeb.Router)
end
