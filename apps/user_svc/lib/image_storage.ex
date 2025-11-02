defmodule ImageStorage do
  @moduledoc """
  Stateless storage layer for images awaiting conversion.

  This module is a thin wrapper around the Storage module (MinIO/S3).
  It provides a simpler API for the controllers.

  ## Why Stateless?
  - Can scale horizontally across multiple nodes
  - No state to lose on restart/crash
  - MinIO is the single source of truth
  - Presigned URLs are generated on-demand (they expire anyway)
  - No memory overhead for caching
  """

  require Logger

  @doc """
  Store image in MinIO and return storage_id.

  ## Examples
      iex> ImageStorage.store(png_binary, "user123", "png")
      {:ok, storage_id}
  """
  def store(image_binary, user_id, format \\ "png") when is_binary(image_binary) do
    case Storage.store(image_binary, user_id, format) do
      {:ok, %{storage_id: storage_id, size: size}} ->
        Logger.info("[ImageStorage] Stored #{storage_id} for user #{user_id} (#{size} bytes)")
        {:ok, storage_id}

      {:error, reason} ->
        Logger.error("[ImageStorage] Failed to store: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Retrieve an image by storage_id from MinIO.

  Returns {:ok, binary} or {:error, reason}
  """
  def fetch(storage_id) do
    case Storage.fetch(storage_id) do
      {:ok, binary} ->
        Logger.info("[ImageStorage] Retrieved #{storage_id} (#{byte_size(binary)} bytes)")
        {:ok, binary}

      {:error, reason} ->
        Logger.error("[ImageStorage] Failed to fetch: #{inspect(reason)}")
        {:error, :not_found}
    end
  end

  @doc """
  Get a presigned URL for a storage_id.

  Generates a fresh presigned URL each time (they expire after 1 hour anyway).
  """
  def get_presigned_url(storage_id) do
    try do
      url = Storage.generate_presigned_url(storage_id)
      Logger.debug("[ImageStorage] Generated presigned URL for #{storage_id}")
      {:ok, url}
    rescue
      error ->
        Logger.warning("[ImageStorage] Failed to generate presigned URL: #{inspect(error)}")
        {:error, :not_found}
    end
  end

  @doc """
  Delete an image from MinIO storage (called after conversion is complete).
  """
  def delete(storage_id) do
    case Storage.delete(storage_id) do
      :ok ->
        Logger.info("[ImageStorage] Deleted #{storage_id}")
        :ok

      {:error, reason} ->
        Logger.warning("[ImageStorage] Failed to delete #{storage_id}: #{inspect(reason)}")
        {:error, :not_found}
    end
  end
end
