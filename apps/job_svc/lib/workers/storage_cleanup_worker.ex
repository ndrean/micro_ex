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
  @spec image_bucket() :: binary()
  defp image_bucket, do: Application.get_env(:job_svc, :image_bucket)

  @spec max_age_seconds() :: integer()
  defp max_age_seconds,
    do: Application.get_env(:job_svc, :image_bucket_max_age) |> String.to_integer()

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: :ok | {:error, any()}
  def perform(_job) do
    Logger.info(
      "[Job][StorageCleanup] Starting cleanup of files older than #{max_age_seconds()}s"
    )

    case list_all_objects() do
      {:ok, objects} ->
        cleanup_old_files(objects)

      {:error, reason} ->
        Logger.error("[Job][StorageCleanup] Failed to list objects: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @spec list_all_objects() :: {:ok, list(map())} | {:error, any()}
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

  @spec cleanup_old_files(list(map())) :: :ok | {:error, any()}
  defp cleanup_old_files(objects) do
    now = System.system_time(:second)
    cutoff_time = now - max_age_seconds()

    deleted_count =
      objects
      |> Enum.filter(&should_delete?(&1.key, cutoff_time))
      |> Enum.map(&delete_object/1)
      |> Enum.count(fn result -> result == :ok end)

    Logger.info("[Job][StorageCleanup] Deleted #{deleted_count} old files")
    :ok
  end

  @spec should_delete?(binary(), integer()) :: boolean()
  defp should_delete?(key, cutoff_time) do
    case parse_timestamp(key) do
      {:ok, timestamp} ->
        timestamp < cutoff_time

      :error ->
        false
    end
  end

  @spec parse_timestamp(binary()) :: {:ok, integer()} | :error
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

  @spec delete_object(map()) :: :ok | {:error, any()}
  defp delete_object(object) do
    case ExAws.S3.delete_object(image_bucket(), object.key) |> ExAws.request() do
      {:ok, _} ->
        Logger.debug("[Job][StorageCleanup] Deleted #{object.key}")
        :ok

      {:error, reason} ->
        Logger.warning("[Job][StorageCleanup] Failed to delete #{object.key}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
