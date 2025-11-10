defmodule ClientServiceWeb.Endpoint do
  @moduledoc false
  use Phoenix.Endpoint, otp_app: :client_svc

  # PromEx metrics endpoint (must be BEFORE Plug.Telemetry to avoid self-instrumentation)
  plug(PromEx.Plug, prom_ex_module: ClientService.PromEx)

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

  # HEAD request support (OPTIONS/HEAD for health checks)
  plug(Plug.Head)

  # Route to controllers
  plug(ClientServiceWeb.Router)
end
