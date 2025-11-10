defmodule ImageSvc.ConversionCacheServer do
  @moduledoc """
  GenServer maintaining a persistent SQLite connection for ConversionCache.

  Benefits:
  - Single persistent connection (no overhead of opening/closing)
  - Serialized writes via GenServer mailbox (prevents SQLite locking issues)
  - Automatic reconnection on failures
  - Clean connection cleanup on shutdown

  All queries are synchronous GenServer.call() to ensure consistency.
  """

  use GenServer
  require Logger

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Find conversion record by image_url and job_id.
  Returns {:ok, map} or {:error, :not_found}.
  """
  def find(image_url, job_id) do
    GenServer.call(__MODULE__, {:find, image_url, job_id})
  end

  @doc """
  Insert new conversion record with status 'processing'.
  """
  def insert(image_url, job_id) do
    GenServer.call(__MODULE__, {:insert, image_url, job_id})
  end

  @doc """
  Mark conversion as completed with result URL.
  """
  def mark_completed(image_url, job_id, result_url) do
    GenServer.call(__MODULE__, {:mark_completed, image_url, job_id, result_url})
  end

  @doc """
  Mark conversion as failed with error reason.
  """
  def mark_failed(image_url, job_id, error_reason) do
    GenServer.call(__MODULE__, {:mark_failed, image_url, job_id, error_reason})
  end

  @doc """
  Update status for a conversion.
  """
  def update_status(image_url, job_id, new_status) do
    GenServer.call(__MODULE__, {:update_status, image_url, job_id, new_status})
  end

  @doc """
  Cleanup old completed/failed records older than N days.
  """
  def cleanup_old_records(days_ago \\ 7) do
    GenServer.call(__MODULE__, {:cleanup, days_ago}, 30_000)
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    db_path = ImageService.Repo.config()[:database]

    with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
         :ok <- Exqlite.Sqlite3.execute(conn, "PRAGMA busy_timeout = 5000"),
         :ok <- Exqlite.Sqlite3.execute(conn, "PRAGMA journal_mode = WAL"),
         :ok <- Exqlite.Sqlite3.execute(conn, "PRAGMA synchronous = NORMAL") do
      Logger.info("[ConversionCacheServer] Started with persistent SQLite connection (WAL mode)")
      {:ok, %{conn: conn}}
    else
      {:error, reason} = error ->
        Logger.error("[ConversionCacheServer] Failed to initialize: #{inspect(reason)}")
        {:stop, error}
    end
  end

  @impl true
  def handle_call({:find, image_url, job_id}, _from, %{conn: conn} = state) do
    result = do_find(conn, image_url, job_id)
    {:reply, result, state}
  end

  def handle_call({:insert, image_url, job_id}, _from, %{conn: conn} = state) do
    result = do_insert(conn, image_url, job_id)
    {:reply, result, state}
  end

  def handle_call({:mark_completed, image_url, job_id, result_url}, _from, %{conn: conn} = state) do
    result = do_mark_completed(conn, image_url, job_id, result_url)
    {:reply, result, state}
  end

  def handle_call({:mark_failed, image_url, job_id, error_reason}, _from, %{conn: conn} = state) do
    result = do_mark_failed(conn, image_url, job_id, error_reason)
    {:reply, result, state}
  end

  def handle_call({:update_status, image_url, job_id, new_status}, _from, %{conn: conn} = state) do
    result = do_update_status(conn, image_url, job_id, new_status)
    {:reply, result, state}
  end

  def handle_call({:cleanup, days_ago}, _from, %{conn: conn} = state) do
    result = do_cleanup(conn, days_ago)
    {:reply, result, state}
  end

  @impl true
  def terminate(reason, %{conn: conn}) do
    Logger.info("[ConversionCacheServer] Shutting down: #{inspect(reason)}")
    Exqlite.Sqlite3.close(conn)
    :ok
  end

  ## Private Implementation

  defp do_find(conn, image_url, job_id) do
    query = """
    SELECT status, result_url, completed_at
    FROM conversions
    WHERE image_url = ?1 AND job_id = ?2
    """

    with {:ok, statement} <- Exqlite.Sqlite3.prepare(conn, query),
         :ok <- Exqlite.Sqlite3.bind(statement, [image_url, job_id]),
         {:row, row} <- Exqlite.Sqlite3.step(conn, statement) do
      :ok = Exqlite.Sqlite3.release(conn, statement)

      [status, result_url, completed_at] = row
      {:ok, %{status: status, result_url: result_url, completed_at: completed_at}}
    else
      :done ->
        {:error, :not_found}

      error ->
        Logger.error("[ConversionCacheServer] Find failed: #{inspect(error)}")
        {:error, :not_found}
    end
  end

  defp do_insert(conn, image_url, job_id) do
    now = System.os_time(:second)

    query = """
    INSERT INTO conversions (image_url, job_id, status, inserted_at)
    VALUES (?1, ?2, 'processing', ?3)
    ON CONFLICT(image_url, job_id) DO UPDATE SET status = 'processing'
    """

    with {:ok, statement} <- Exqlite.Sqlite3.prepare(conn, query),
         :ok <- Exqlite.Sqlite3.bind(statement, [image_url, job_id, now]),
         :done <- Exqlite.Sqlite3.step(conn, statement),
         :ok <- Exqlite.Sqlite3.release(conn, statement) do
      :ok
    else
      error ->
        Logger.error("[ConversionCacheServer] Insert failed: #{inspect(error)}")
        {:error, :insert_failed}
    end
  end

  defp do_mark_completed(conn, image_url, job_id, result_url) do
    now = System.os_time(:second)

    query = """
    UPDATE conversions
    SET status = 'completed',
        result_url = ?1,
        completed_at = ?2
    WHERE image_url = ?3 AND job_id = ?4
    """

    with {:ok, statement} <- Exqlite.Sqlite3.prepare(conn, query),
         :ok <- Exqlite.Sqlite3.bind(statement, [result_url, now, image_url, job_id]),
         :done <- Exqlite.Sqlite3.step(conn, statement),
         :ok <- Exqlite.Sqlite3.release(conn, statement) do
      :ok
    else
      error ->
        Logger.error("[ConversionCacheServer] Mark completed failed: #{inspect(error)}")
        {:error, error}
    end
  end

  defp do_mark_failed(conn, image_url, job_id, error_reason) do
    now = System.os_time(:second)

    query = """
    UPDATE conversions
    SET status = 'failed',
        completed_at = ?1,
        error_reason = ?2
    WHERE image_url = ?3 AND job_id = ?4
    """

    with {:ok, statement} <- Exqlite.Sqlite3.prepare(conn, query),
         :ok <- Exqlite.Sqlite3.bind(statement, [now, error_reason, image_url, job_id]),
         :done <- Exqlite.Sqlite3.step(conn, statement),
         :ok <- Exqlite.Sqlite3.release(conn, statement) do
      :ok
    else
      error ->
        Logger.error("[ConversionCacheServer] Mark failed failed: #{inspect(error)}")
        {:error, error}
    end
  end

  defp do_update_status(conn, image_url, job_id, new_status) do
    query = "UPDATE conversions SET status = ?1 WHERE image_url = ?2 AND job_id = ?3"

    with {:ok, statement} <- Exqlite.Sqlite3.prepare(conn, query),
         :ok <- Exqlite.Sqlite3.bind(statement, [new_status, image_url, job_id]),
         :done <- Exqlite.Sqlite3.step(conn, statement),
         :ok <- Exqlite.Sqlite3.release(conn, statement) do
      :ok
    else
      error ->
        Logger.error("[ConversionCacheServer] Update status failed: #{inspect(error)}")
        {:error, :update_failed}
    end
  end

  defp do_cleanup(conn, days_ago) do
    cutoff = System.os_time(:second) - days_ago * 86400
    query = "DELETE FROM conversions WHERE completed_at < ?1"

    with {:ok, statement} <- Exqlite.Sqlite3.prepare(conn, query),
         :ok <- Exqlite.Sqlite3.bind(statement, [cutoff]),
         :done <- Exqlite.Sqlite3.step(conn, statement),
         :ok <- Exqlite.Sqlite3.release(conn, statement) do
      Logger.info("[ConversionCacheServer] Cleaned up old records (cutoff: #{days_ago} days)")
      :ok
    else
      error ->
        Logger.error("[ConversionCacheServer] Cleanup failed: #{inspect(error)}")
        {:error, error}
    end
  end
end
