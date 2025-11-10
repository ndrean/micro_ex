defmodule ImageSvc.MetadataCache do
  @moduledoc """
  ETS-backed in-memory cache for image metadata.

  Use this for frequently accessed image metadata (dimensions, format, etc.)
  to avoid hitting SQLite or MinIO repeatedly.

  Performance:
  - SQLite lookup: ~0.5-2ms
  - ETS lookup: ~0.001-0.005ms (100-1000x faster!)
  - Concurrency: Lock-free reads, millions of ops/sec
  """

  use GenServer
  require Logger

  @table_name :image_metadata_cache
  @ttl_seconds 3600  # 1 hour TTL

  ## Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Get metadata from cache. Returns:
  - {:ok, metadata} - Cache hit
  - :miss - Cache miss, fetch from source
  """
  def get(job_id) do
    case :ets.lookup(@table_name, job_id) do
      [{^job_id, metadata, expires_at}] ->
        if System.os_time(:second) < expires_at do
          {:ok, metadata}
        else
          :ets.delete(@table_name, job_id)
          :miss
        end

      [] ->
        :miss
    end
  end

  @doc """
  Put metadata in cache with TTL.
  """
  def put(job_id, metadata, ttl_seconds \\ @ttl_seconds) do
    expires_at = System.os_time(:second) + ttl_seconds
    :ets.insert(@table_name, {job_id, metadata, expires_at})
    :ok
  end

  @doc """
  Invalidate cache entry.
  """
  def invalidate(job_id) do
    :ets.delete(@table_name, job_id)
  end

  @doc """
  Get cache statistics.
  """
  def stats do
    info = :ets.info(@table_name)

    %{
      size: info[:size],
      memory_bytes: info[:memory] * :erlang.system_info(:wordsize),
      memory_mb: info[:memory] * :erlang.system_info(:wordsize) / 1_024 / 1_024
    }
  end

  ## GenServer Callbacks

  @impl true
  def init(:ok) do
    # Create ETS table with optimized settings
    :ets.new(@table_name, [
      :set,                    # Key-value store
      :public,                 # Any process can read/write
      :named_table,            # Access by name
      read_concurrency: true,  # Optimize for concurrent reads
      write_concurrency: true, # Optimize for concurrent writes
      decentralized_counters: true  # Better concurrency on multi-core
    ])

    Logger.info("[MetadataCache] ETS table created: #{@table_name}")

    # Schedule periodic cleanup of expired entries
    schedule_cleanup()

    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup_expired, state) do
    now = System.os_time(:second)

    # Delete expired entries
    deleted = :ets.select_delete(@table_name, [
      {{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}
    ])

    if deleted > 0 do
      Logger.debug("[MetadataCache] Cleaned up #{deleted} expired entries")
    end

    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    # Run cleanup every 5 minutes
    Process.send_after(self(), :cleanup_expired, 5 * 60 * 1000)
  end
end
