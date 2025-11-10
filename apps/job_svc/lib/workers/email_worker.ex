defmodule JobService.Workers.EmailWorker do
  @moduledoc """
  Oban worker for sending emails asynchronously via EmailService.

  This worker:
  1. Receives email job from Oban queue
  2. Calls EmailService to send the email
  3. Notifies JobService about delivery status via callback
  """

  use Oban.Worker,
    queue: :emails,
    max_attempts: 3,
    priority: 1

  require Logger

  alias JobService.Clients.EmailSvcClient

  @impl Oban.Worker

  @spec perform(Oban.Job.t()) :: :ok | {:error, any()}
  def perform(%Oban.Job{args: args} = _job) do
    Logger.info("[Job][EmailWorker] Received job with args: #{inspect(args)}")
    do_perform(args)
  end

  defp do_perform(%{"type" => "welcome"} = args) do
    # Extract and attach OpenTelemetry trace context from job args
    :ok = attach_trace_context(args)

    Logger.info("[Job][EmailWorker] Sending #{args["type"]} email to user #{args["id"]}")

    EmailSvcClient.send_email(args)
  end

  defp do_perform(%{"type" => "notification"} = args) do
    # Extract and attach OpenTelemetry trace context from job args
    :ok =
      attach_trace_context(args)

    Logger.info("[Job][EmailWorker] Sending notification email to user #{args["user_id"]}")

    EmailSvcClient.send_email(args)
  end

  defp do_perform(args) do
    Logger.error("[Job][EmailWorker] Unknown email type: #{inspect(args)}")
    {:error, "[Job] Unknown email type"}
  end

  # Extract OpenTelemetry trace context from job args and attach to current process
  @spec attach_trace_context(map()) :: :ok
  defp attach_trace_context(%{"_otel_trace_context" => trace_context} = _args)
       when is_map(trace_context) do
    # Convert map back to list of tuples for extraction
    trace_headers = Enum.into(trace_context, [])

    :otel_propagator_text_map.extract(trace_headers)
    :ok
  end

  defp attach_trace_context(_args), do: :ok
end
