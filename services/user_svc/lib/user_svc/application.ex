defmodule UserSvc.Application do
  use Application
  # require OpenTelemetry.Tracer

  @moduledoc """
  Entry point
  """
  require Logger

  defp image_bucket, do: Application.get_env(:user_svc, :image_bucket)
  defp loki_chunks, do: Application.get_env(:user_svc, :loki_chunks)

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:user_svc, :port, 8081)
    Logger.info("Starting USER Service on port #{port}")
    ensure_minio_bucket()

    children = [
      UserSvc.PromEx,
      UserSvcWeb.Telemetry,
      UserSvcWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: UserSvc.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp ensure_minio_bucket do
    # buckets = ["msvc-images", "loki-chunks"]
    buckets = [image_bucket(), loki_chunks()]

    Logger.info("[MinIO] Ensuring bucket '#{image_bucket()}' exists")

    [:ok, :ok] =
      for bucket <- buckets do
        case ExAws.S3.head_bucket(bucket) |> ExAws.request() do
          {:ok, _} ->
            Logger.info("[MinIO] Bucket '#{bucket}' already exists")
            :ok

          {:error, {:http_error, 404, _}} ->
            Logger.info("[MinIO] Creating bucket '#{bucket}'")

            case ExAws.S3.put_bucket(bucket, "us-east-1") |> ExAws.request() do
              {:ok, _} ->
                Logger.info("[MinIO] Bucket '#{bucket}' created successfully")
                :ok

              {:error, reason} ->
                Logger.error("[MinIO] Failed to create bucket: #{inspect(reason)}")
                {:error, reason}
            end
        end
      end
  end
end
