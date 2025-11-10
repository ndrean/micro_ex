defmodule ImageSvc.ConversionCache do
  @moduledoc """
  SQLite-backed cache for image conversion idempotence.

  Ensures the same image_url + job_id combination is only processed once,
  even if Oban retries the job due to transient failures.

  This module delegates to ConversionCacheServer (GenServer) which maintains
  a persistent SQLite connection for better performance and concurrency.

  Schema:
    - image_url (TEXT, indexed)
    - job_id (TEXT, indexed)
    - result_url (TEXT) - S3 URL of converted PDF
    - status (TEXT) - "processing" | "completed" | "failed"
    - inserted_at (INTEGER) - Unix timestamp
    - completed_at (INTEGER, nullable)

  Composite unique index on (image_url, job_id) ensures idempotence.
  """

  require Logger
  alias ImageSvc.ConversionCacheServer

  ## Public API

  @doc """
  Find or create a conversion record. Returns:
  - {:ok, :found, result_url} - Already processed, return cached result
  - {:ok, :created} - New record, proceed with conversion
  - {:error, :processing} - Currently being processed by another worker
  """
  def find_or_create(image_url, job_id) do
    case ConversionCacheServer.find(image_url, job_id) do
      {:ok, %{status: "completed", result_url: url}} ->
        Logger.info("[Image][ConversionCache] Hit: #{job_id} - returning cached result")
        {:ok, :found, url}

      {:ok, %{status: "processing"}} ->
        Logger.warning("[Image][ConversionCache] Duplicate: #{job_id} - already processing")
        {:error, :processing}

      {:ok, %{status: "failed"}} ->
        # Allow retry for failed conversions
        Logger.info("[Image][ConversionCache] Retrying failed conversion: #{job_id}")
        ConversionCacheServer.update_status(image_url, job_id, "processing")
        {:ok, :created}

      {:error, :not_found} ->
        ConversionCacheServer.insert(image_url, job_id)
        {:ok, :created}
    end
  end

  @doc """
  Mark conversion as completed with result URL.
  """
  def mark_completed(image_url, job_id, result_url) do
    case ConversionCacheServer.mark_completed(image_url, job_id, result_url) do
      :ok ->
        Logger.info("[Image][ConversionCache] Marked completed: #{job_id}")
        :ok

      error ->
        Logger.error("[Image][ConversionCache] Mark completed failed: #{inspect(error)}")
        error
    end
  end

  @doc """
  Mark conversion as failed.
  """
  def mark_failed(image_url, job_id, error_reason) do
    case ConversionCacheServer.mark_failed(image_url, job_id, error_reason) do
      :ok ->
        Logger.info("[Image][ConversionCache] Marked failed: #{job_id}")
        :ok

      error ->
        Logger.error("[Image][ConversionCache] Mark failed failed: #{inspect(error)}")
        error
    end
  end

  @doc """
  Cleanup old records (older than 7 days).
  Call this periodically via Oban scheduled job.
  """
  def cleanup_old_records(days_ago \\ 1) do
    ConversionCacheServer.cleanup_old_records(days_ago)
  end
end
