# defmodule JobRouter do
#   @moduledoc false
#   use Plug.Router
#   import Ecto.Query

#   # Request ID for correlation across services
#   plug(Plug.RequestId)

#   # Logger with request_id metadata
#   plug(Plug.Logger, log: :info)

#   # PromEx metrics plug (must be before Plug.Telemetry to avoid metrics pollution)
#   plug(PromEx.Plug, prom_ex_module: JobSvc.PromEx)

#   # Telemetry for metrics
#   plug(Plug.Telemetry, event_prefix: [:job_svc, :plug])

#   # Extract OpenTelemetry trace context from incoming requests
#   plug(JobSvc.OpenTelemetryPlug)

#   plug(:match)

#   plug(Plug.Parsers,
#     parsers: [:json],
#     json_decoder: Jason,
#     # Skip parsing protobuf, let us handle it manually
#     pass: ["application/protobuf", "application/x-protobuf"]
#   )

#   plug(:dispatch)

#   # RPC-style protobuf endpoints (matches services.proto)

#   # JobService.EnqueueEmail - Enqueue email job in Oban
#   post "/job_svc/enqueue_email/v1" do
#     EmailSenderController.enqueue(conn)
#   end

#   # JobService.NotifyEmailDelivery - Receive delivery status from email_svc
#   post "/job_svc/notify_email_delivery/v1" do
#     EmailNotificationController.notify(conn)
#   end

#   # JobService.ConvertImage - Enqueue image conversion job
#   post "/job_svc/convert_image/v1" do
#     ImageController.convert(conn)
#   end

#   # Health check endpoints
#   match "/health", via: [:get, :head] do
#     # Simple liveness check
#     send_resp(conn, 200, "OK")
#   end

#   # get "/health/ready" do
#   #   # Readiness check - verify dependencies
#   #   # TODO: Check MinIO, user_svc connectivity
#   #   send_resp(conn, 200, "READY")
#   # end

#   # Debug endpoints
#   get "/debug/db" do
#     # Test database connectivity
#     case Ecto.Adapters.SQL.query(JobService.Repo, "SELECT 1 as test", []) do
#       {:ok, %{rows: [[1]]}} ->
#         conn
#         |> put_resp_content_type("application/json")
#         |> send_resp(200, Jason.encode!(%{status: "ok", database: "connected", result: 1}))

#       {:error, reason} ->
#         conn
#         |> put_resp_content_type("application/json")
#         |> send_resp(500, Jason.encode!(%{status: "error", reason: inspect(reason)}))
#     end
#   end

#   get "/debug/queue" do
#     # Get Oban queue statistics

#     # Count jobs by state
#     stats =
#       from(j in Oban.Job,
#         group_by: [j.state, j.queue],
#         select: %{
#           queue: j.queue,
#           state: j.state,
#           count: count(j.id)
#         }
#       )
#       |> JobService.Repo.all()
#       |> Enum.group_by(& &1.queue)
#       |> Enum.map(fn {queue, jobs} ->
#         state_counts = Enum.map(jobs, fn j -> {j.state, j.count} end) |> Enum.into(%{})
#         {queue, state_counts}
#       end)
#       |> Enum.into(%{})

#     # Get recent jobs (last 10)
#     recent_jobs =
#       from(j in Oban.Job,
#         order_by: [desc: j.id],
#         limit: 10,
#         select: %{
#           id: j.id,
#           queue: j.queue,
#           worker: j.worker,
#           state: j.state,
#           attempt: j.attempt,
#           max_attempts: j.max_attempts,
#           inserted_at: j.inserted_at,
#           scheduled_at: j.scheduled_at,
#           attempted_at: j.attempted_at,
#           completed_at: j.completed_at
#         }
#       )
#       |> JobService.Repo.all()

#     response = %{
#       status: "ok",
#       queue_stats: stats,
#       recent_jobs: recent_jobs,
#       timestamp: DateTime.utc_now()
#     }

#     conn
#     |> put_resp_content_type("application/json")
#     |> send_resp(200, Jason.encode!(response, pretty: true))
#   end

#   # Prometheus metrics endpoint (now handled by PromEx.Plug)
#   # get "/metrics" do
#   #   metrics = TelemetryMetricsPrometheus.Core.scrape(:job_svc_metrics)
#   #
#   #   conn
#   #   |> put_resp_content_type("text/plain; version=0.0.4")
#   #   |> send_resp(200, metrics)
#   # end

#   match _ do
#     send_resp(conn, 404, "Not Found")
#   end
# end
