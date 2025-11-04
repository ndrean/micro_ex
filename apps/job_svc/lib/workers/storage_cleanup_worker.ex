defmodule StorageCleanupWorker do
  @moduledoc """
  Periodic cleanup job (15min) that deletes images older than 1 hour from MinIO.

  Storage ID format: {unix_timestamp_microseconds}_{random_string}.{extension}
  Example: 1762116318937316_7CjhIdQpjf8.pdf

  Runs every 15 minutes via Oban crontab.
  """

  use Oban.Worker, queue: :cleanup, max_attempts: 3

  require Logger

  # @bucket "msvc-images"
  # @max_age_seconds 3600
  defp image_bucket, do: Application.get_env(:job_svc, :image_bucket)

  defp max_age_seconds,
    do: Application.get_env(:job_svc, :image_bucket_max_age) |> String.to_integer()

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("[StorageCleanup] Starting cleanup of files older than #{max_age_seconds()}s")

    case list_all_objects() do
      {:ok, objects} ->
        cleanup_old_files(objects)

      {:error, reason} ->
        Logger.error("[StorageCleanup] Failed to list objects: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp list_all_objects do
    request =
      image_bucket()
      |> ExAws.S3.list_objects()
      |> ExAws.request()

    case request do
      {:ok, %{body: %{contents: objects}}} ->
        {:ok, objects}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp cleanup_old_files(objects) do
    now = System.system_time(:second)
    cutoff_time = now - max_age_seconds()

    deleted_count =
      objects
      |> Enum.filter(&should_delete?(&1.key, cutoff_time))
      |> Enum.map(&delete_object/1)
      |> Enum.count(fn result -> result == :ok end)

    Logger.info("[StorageCleanup] Deleted #{deleted_count} old files")
    :ok
  end

  defp should_delete?(key, cutoff_time) do
    case parse_timestamp(key) do
      {:ok, timestamp} ->
        timestamp < cutoff_time

      :error ->
        false
    end
  end

  defp parse_timestamp(key) do
    # Extract timestamp from key: "1762116318937316_7CjhIdQpjf8.pdf"
    #  {unix_timestamp_microseconds}_{random_string}.{extension}
    case String.split(key, "_") do
      [timestamp_str | _] ->
        # Timestamp is in microseconds, convert to seconds
        case Integer.parse(timestamp_str) do
          {timestamp_us, ""} ->
            {:ok, div(timestamp_us, 1_000_000)}

          _ ->
            :error
        end

      _ ->
        :error
    end
  end

  defp delete_object(object) do
    case ExAws.S3.delete_object(image_bucket(), object.key) |> ExAws.request() do
      {:ok, _} ->
        Logger.debug("[StorageCleanup] Deleted #{object.key}")
        :ok

      {:error, reason} ->
        Logger.warning("[StorageCleanup] Failed to delete #{object.key}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
