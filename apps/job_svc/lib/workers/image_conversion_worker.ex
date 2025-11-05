defmodule JobService.Workers.ImageConversionWorker do
  @moduledoc """
  Oban worker for orchestrating image conversions.

  This worker:
  1. Receives job metadata from Oban
  2. Sends HTTP request to image_svc with image URL
  3. image_svc handles conversion and sends result directly to user_svc

  ## Workflow

  Client → UserService → JobService (enqueue) → ImageConversionWorker (async)
    → HTTP to image_svc → image_svc converts → image_svc sends to user_svc

  ## Queue Configuration

  Add to config.exs:

      config :job_svc, Oban,
        queues: [
          images: 10  # Process 10 images concurrently
        ]
  """

  use Oban.Worker,
    queue: :images,
    max_attempts: 3,
    priority: 2

  require Logger

  @impl Oban.Worker

  @spec perform(Oban.Job.t()) :: :ok | {:error, any()}
  def perform(%Oban.Job{args: args}) do
    # Extract and attach OpenTelemetry trace context from job args
    attach_trace_context(args)

    Logger.info(
      "[ImageConversionWorker] Processing conversion for user #{args["user_id"]} (#{args["user_email"]})"
    )

    case JobService.Clients.ImageSvcClient.convert_image(args) do
      :ok ->
        Logger.info("[ImageConversionWorker] Conversion completed successfully")
        :ok

      {:error, reason} ->
        Logger.error("[ImageConversionWorker] Conversion failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Extract OpenTelemetry trace context from job args and attach to current process
  @spec attach_trace_context(map()) :: :ok
  defp attach_trace_context(%{"_otel_trace_context" => trace_context})
       when is_map(trace_context) do
    # Convert map back to list of tuples for extraction
    trace_headers = Enum.into(trace_context, [])
    :otel_propagator_text_map.extract(trace_headers)
  end

  defp attach_trace_context(_args), do: :ok
end
