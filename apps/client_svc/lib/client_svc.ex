defmodule Client do
  @moduledoc """
  Documentation for `ClientSvc`.
  """
  require Logger
  require OpenTelemetry.Tracer, as: Tracer
  require OpenTelemetry.Span, as: Span
  # Code.require_file("priv/user.pb.ex") |> dbg()

  # No need for Code.require_file!
  # Mix automatically compiles all .ex files in lib/
  # Just reference the module directly: Mcsv.UserRequest

  # Runtime config - reads from runtime.exs via environment variables
  defp base_user_url, do: Application.get_env(:client_svc, :user_svc_base_url)
  defp user_endpoints, do: Application.get_env(:client_svc, :user_endpoints)

  @doc """
  Create a single user synchronously.

  ## Examples

      iex> Client.create(1)
      %Mcsv.UserResponse{ok: true, message: "..."}
  """
  def create(i) do
    Tracer.with_span "#{__MODULE__}.create/1" do
      Tracer.set_attribute(:value, i)
      :ok
    end

    %Mcsv.UserRequest{
      id: "#{i}",
      name: "PB User #{i}",
      email: "pbuser#{i}@example.com",
      bio: String.duplicate("bio for #{i} ", 1),
      type: "welcome"
    }
    |> post(base_user_url(), user_endpoints().create)
    |> case do
      {:ok, %Req.Response{} = resp} ->
        Mcsv.UserResponse.decode(resp.body)

      {:error, reason} ->
        raise inspect(reason)
    end
  end

  @doc """
  Create multiple users concurrently.

  ## Parameters

    - count: Number of users to create (default: 100)
    - concurrency: Max concurrent HTTP requests (default: 10)

  ## Examples

      # Create 100 users with 10 concurrent requests
      iex> Client.stream_users()
      {100, 0}  # {success_count, failed_count}

      # Create 1000 users with 50 concurrent requests
      iex> Client.stream_users(1000, 50)
      {1000, 0}

  ## Returns

    {success_count, failed_count}
  """
  def stream_users(_count \\ 100, concurrency \\ 10) do
    # Stream.iterate(1, &(&1 + 1))

    # 1..count

    # Capture current OpenTelemetry context to propagate to spawned tasks
    ctx = OpenTelemetry.Ctx.get_current()

    Stream.interval(10)
    |> Task.async_stream(
      fn i ->
        # Attach parent context in spawned process
        OpenTelemetry.Ctx.attach(ctx)

        # Build and send each user request
        %Mcsv.UserRequest{
          id: "#{i}",
          name: "StreamUser #{i}",
          email: "streamuser#{i}@example.com",
          bio: String.duplicate("bio for #{i} ", 5),
          type: "welcome"
        }
        |> post(base_user_url(), user_endpoints().create)
      end,
      ordered: false,
      max_concurrency: concurrency,
      # 30 seconds per request
      timeout: 30_000
    )
    |> Enum.reduce({0, 0}, fn
      {:ok, %{status: 200}}, {success, failed} ->
        {success + 1, failed}

      {:ok, _resp}, {success, failed} ->
        {success, failed + 1}

      {:exit, _reason}, {success, failed} ->
        {success, failed + 1}
    end)
    |> then(fn {success, failed} ->
      Logger.info("Completed: #{success} successful, #{failed} failed")
      {success, failed}
    end)
  end

  defp post(%Mcsv.UserRequest{} = user, base, uri) do
    binary = Mcsv.UserRequest.encode(user)

    Req.new(base_url: base)
    |> OpentelemetryReq.attach(propagate_trace_headers: true)
    |> Req.post(
      url: uri,
      body: binary,
      headers: [{"content-type", "application/protobuf"}]
    )
  end
end
