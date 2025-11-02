defmodule UserApp do
  use Application
  require OpenTelemetry.Tracer

  @moduledoc """
  Entry point
  """
  require Logger

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:user_svc, :port, 8081)
    Logger.info("Starting USER Server on port #{port}")

    Logger.metadata(service: "user_svc")

    # Ensure MinIO bucket exists
    ensure_minio_bucket()

    children = [
      UserSvc.Metrics,
      {Bandit, plug: UserRouter, port: 8081}
    ]

    opts = [strategy: :one_for_one, name: UserSvc.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp ensure_minio_bucket do
    bucket = "msvc-images"

    Logger.info("[MinIO] Ensuring bucket '#{bucket}' exists")

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

      {:error, reason} ->
        Logger.error("[MinIO] Failed to check bucket: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
