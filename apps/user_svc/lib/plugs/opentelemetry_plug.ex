defmodule UserSvc.OpenTelemetryPlug do
  @moduledoc """
  Extracts OpenTelemetry trace context from incoming HTTP headers
  and creates a server span for distributed tracing.

  This plug must be placed BEFORE :match in the router.
  """

  import Plug.Conn
  require OpenTelemetry.Tracer

  def init(opts), do: opts

  def call(conn, _opts) do
    # Extract trace context from incoming headers (traceparent, tracestate)
    # conn.req_headers is already a list of {key, value} tuples
    # This sets the current OpenTelemetry context in the process dictionary
    :otel_propagator_text_map.extract(conn.req_headers)

    # Start a server span for this incoming request
    # It will automatically use the extracted context as parent
    span_name = "#{conn.method} #{conn.request_path}"
    OpenTelemetry.Tracer.start_span(span_name, %{kind: :server})

    # Set HTTP semantic convention attributes
    OpenTelemetry.Tracer.set_attributes([
      {"http.method", conn.method},
      {"http.target", conn.request_path},
      {"http.scheme", to_string(conn.scheme)},
      {"http.host", conn.host}
    ])

    # Register callback to end span after response is sent
    register_before_send(conn, fn conn ->
      # Set response status code
      OpenTelemetry.Tracer.set_attribute("http.status_code", conn.status)
      # End the span
      OpenTelemetry.Tracer.end_span()
      conn
    end)
  end
end
