defmodule UserRouter do
  use Plug.Router

  @moduledoc false

  # Request ID for correlation across services
  plug(Plug.RequestId)
  # Logger with request_id metadata
  plug(Plug.Logger, log: :info)
  # Telemetry for metrics
  plug(Plug.Telemetry, event_prefix: [:user_svc, :plug])
  # Extract OpenTelemetry trace context from incoming requests
  plug(UserSvc.OpenTelemetryPlug)

  plug(:match)

  plug(Plug.Parsers,
    parsers: [:json],
    json_decoder: Jason,
    pass: ["application/protobuf"]
  )

  plug(:dispatch)

  # RPC-style protobuf endpoints (matches services.proto)

  # UserService.CreateUser - Create user and trigger email workflow
  post "/user_svc/CreateUser" do
    CreateUserController.create(conn)
  end

  # UserService.NotifyEmailSent - Receive callback from job_svc
  post "/user_svc/NotifyEmailSent" do
    ForwardEmailNotificationController.forward(conn)
  end

  # UserService.ConvertImage - Initiate image conversion workflow
  post "/user_svc/ConvertImage" do
    ConvertImageController.convert(conn)
  end

  # UserService.ImageLoader - Serve stored images to other services
  get "/user_svc/ImageLoader/:job_id" do
    ImageLoaderController.load(conn, job_id)
  end

  # UserService.StoreImage - Store image/PDF in MinIO and return presigned URL
  post "/user_svc/StoreImage" do
    StoreImageController.store(conn)
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
    metrics = TelemetryMetricsPrometheus.Core.scrape(:user_svc_metrics)

    conn
    |> put_resp_content_type("text/plain; version=0.0.4")
    |> send_resp(200, metrics)
  end

  # # Stream-style endpoint - send user, get chunked responses
  # post "/user/stream" do
  #   case conn.body_params do
  #     %{"id" => _id, "name" => _name, "email" => _email, "age" => _age, "active" => _active} ->
  #       # IO.puts("[HTTP Server] Received user for streaming: #{name} (#{email})")

  #       # Set up chunked transfer encoding
  #       conn =
  #         conn
  #         |> put_resp_content_type("application/json")
  #         |> send_chunked(200)

  #       # Send multiple chunks
  #       responses = [
  #         %{"ok" => true, "message" => "Processing user..."},
  #         %{"ok" => true, "message" => "Validating user..."},
  #         %{"ok" => true, "message" => "User saved successfully"}
  #       ]

  #       Enum.reduce(responses, conn, fn response, conn ->
  #         chunk_data = Jason.encode!(response) <> "\n"
  #         {:ok, conn} = chunk(conn, chunk_data)
  #         conn
  #       end)

  #     _ ->
  #       error_response = %{
  #         "ok" => false,
  #         "message" => "Invalid user data"
  #       }

  #       conn
  #       |> put_resp_content_type("application/json")
  #       |> send_resp(400, Jason.encode!(error_response))
  #   end
  # end

  # # Progressive streaming endpoint - sends events over time
  # get "/events" do
  #   events = [
  #     %{event: "start", message: "Connection established"},
  #     %{event: "processing", message: "Processing user data..."},
  #     %{event: "validation", message: "Validating fields..."},
  #     %{event: "database", message: "Saving to database..."},
  #     %{event: "complete", message: "Operation successful!"}
  #   ]

  #   # len = :binary.list_to_bin(events)|> length() |> dbg()
  #   conn =
  #     conn
  #     |> put_resp_content_type("text/event-stream")
  #     # |> put_resp_header("content-length",  len)
  #     |> send_chunked(200)

  #   Enum.reduce(events, conn, fn event, conn ->
  #     # Send as JSON line
  #     data = Jason.encode!(event) <> "\n"
  #     {:ok, conn} = Plug.Conn.chunk(conn, data)
  #     conn
  #   end)
  # end

  # # SSE-style continuous stream endpoint
  # get "/stream/:count" do
  #   count = String.to_integer(count)

  #   conn =
  #     conn
  #     |> put_resp_content_type("text/event-stream")
  #     |> put_resp_header("cache-control", "no-cache")
  #     |> put_resp_header("connection", "keep-alive")
  #     |> send_chunked(200)

  #   # Send count events with delays
  #   Enum.reduce(1..count, conn, fn i, conn ->
  #     Process.sleep(100)

  #     event = %{
  #       id: i,
  #       event_count: "Event #{i} of #{count}",
  #       timestamp: System.system_time(:millisecond)
  #     }

  #     chunk_data = "data: #{Jason.encode!(event)}\n\n"
  #     {:ok, conn} = chunk(conn, chunk_data)
  #     conn
  #   end)
  # end

  match _ do
    send_resp(conn, 404, "Not found")
  end
end
