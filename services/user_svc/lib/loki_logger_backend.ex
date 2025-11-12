# defmodule LokiLoggerBackend do
#   @moduledoc """
#   Custom Logger backend that pushes logs to Loki via Broadway pipeline.

#   Architecture:
#     Logger.info() → handle_event() → Broadway.push_messages()
#                                         ↓
#                                     Batcher (100 logs)
#                                         ↓
#                                     HTTP POST to Loki

#   Benefits:
#   - Async: Logging never blocks request handling
#   - Batched: Efficient HTTP requests (100 logs per POST)
#   - Backpressure: Broadway handles memory overflow
#   - Resilient: Retry logic for failed batches
#   """

#   @behaviour :gen_event

#   # GenEvent callbacks (Logger backend)

#   def init(__MODULE__) do
#     # Start the Broadway pipeline for async processing
#     {:ok, _pid} = LokiLoggerBackend.Pipeline.start_link()
#     {:ok, configure([])}
#   end

#   def handle_call({:configure, options}, state) do
#     {:ok, :ok, configure(options, state)}
#   end

#   def handle_event({level, _gl, {Logger, msg, ts, metadata}}, state) do
#     # Don't block! Just push to Broadway and return immediately
#     if meet_level?(level, state.level) do
#       message = %{
#         level: level,
#         message: IO.iodata_to_binary(msg),
#         timestamp: format_timestamp(ts),
#         metadata: take_metadata(metadata, state.metadata),
#         service: state.service
#       }

#       # Non-blocking push to Broadway
#       Broadway.push_messages(LokiLoggerBackend.Pipeline, [
#         %Broadway.Message{
#           data: message,
#           acknowledger: {__MODULE__, :ack_id, :ack_data}
#         }
#       ])
#     end

#     {:ok, state}
#   end

#   def handle_event(:flush, state) do
#     {:ok, state}
#   end

#   def handle_info(_msg, state) do
#     {:ok, state}
#   end

#   def code_change(_old_vsn, state, _extra) do
#     {:ok, state}
#   end

#   def terminate(_reason, _state) do
#     :ok
#   end

#   # Helpers

#   defp configure(options, state \\ %{}) do
#     config = Keyword.merge(Application.get_env(:logger, __MODULE__, []), options)

#     %{
#       level: Keyword.get(config, :level, :info),
#       metadata: Keyword.get(config, :metadata, [:request_id]),
#       service: Keyword.get(config, :service, "unknown"),
#       loki_url: Keyword.get(config, :loki_url, "http://localhost:3100")
#     }
#   end

#   defp meet_level?(lvl, min) do
#     Logger.compare_levels(lvl, min) != :lt
#   end

#   defp take_metadata(metadata, :all), do: metadata
#   defp take_metadata(metadata, keys), do: Keyword.take(metadata, keys)

#   defp format_timestamp({{year, month, day}, {hour, min, sec, milli}}) do
#     # RFC3339 format for Loki
#     "#{year}-#{pad(month)}-#{pad(day)}T#{pad(hour)}:#{pad(min)}:#{pad(sec)}.#{pad(milli, 3)}Z"
#   end

#   defp pad(int, count \\ 2), do: String.pad_leading(to_string(int), count, "0")
# end

# defmodule LokiLoggerBackend.Pipeline do
#   @moduledoc """
#   Broadway pipeline that batches logs and sends to Loki.

#   Flow:
#     1. Receive log messages from Logger backend
#     2. Batch them (100 logs or 1 second timeout)
#     3. POST batch to Loki via HTTP
#     4. Retry on failure (exponential backoff)
#   """

#   use Broadway

#   def start_link(_opts \\ []) do
#     config = Application.get_env(:logger, LokiLoggerBackend, [])

#     Broadway.start_link(__MODULE__,
#       name: __MODULE__,
#       producer: [
#         module: {Broadway.DummyProducer, []},
#         # Using DummyProducer because Logger backend will push_messages directly
#         concurrency: 1
#       ],
#       processors: [
#         default: [
#           concurrency: 2,
#           min_demand: 10,
#           max_demand: 100
#         ]
#       ],
#       batchers: [
#         loki: [
#           concurrency: 1,
#           batch_size: 100,        # Batch 100 logs
#           batch_timeout: 1000     # Or wait max 1 second
#         ]
#       ],
#       context: %{
#         loki_url: Keyword.get(config, :loki_url, "http://localhost:3100")
#       }
#     )
#   end

#   @impl true
#   def handle_message(_processor, message, _context) do
#     # Just pass through - batching happens next
#     Broadway.Message.put_batcher(message, :loki)
#   end

#   @impl true
#   def handle_batch(:loki, messages, _batch_info, context) do
#     # Extract log data
#     logs = Enum.map(messages, & &1.data)

#     # Build Loki payload
#     payload = build_loki_payload(logs)

#     # POST to Loki with retry
#     case post_to_loki(context.loki_url, payload) do
#       {:ok, _response} ->
#         # Success - acknowledge all messages
#         messages

#       {:error, reason} ->
#         # Retry logic: mark messages as failed
#         # Broadway will retry based on handle_failed configuration
#         IO.puts("[LokiLogger] Failed to send batch: #{inspect(reason)}")
#         Enum.map(messages, &Broadway.Message.failed(&1, reason))
#     end
#   end

#   defp build_loki_payload(logs) do
#     # Group logs by service for efficient Loki streams
#     logs_by_service = Enum.group_by(logs, & &1.service)

#     streams = Enum.map(logs_by_service, fn {service, service_logs} ->
#       %{
#         stream: %{
#           service: service,
#           job: "elixir_microservices"
#         },
#         values: Enum.map(service_logs, fn log ->
#           # [timestamp_nanoseconds, log_line]
#           [
#             timestamp_to_nanoseconds(log.timestamp),
#             build_log_line(log)
#           ]
#         end)
#       }
#     end)

#     %{streams: streams}
#   end

#   defp build_log_line(log) do
#     metadata_str =
#       log.metadata
#       |> Enum.map(fn {k, v} -> "#{k}=#{inspect(v)}" end)
#       |> Enum.join(" ")

#     "level=#{log.level} #{metadata_str} #{log.message}"
#   end

#   defp timestamp_to_nanoseconds(ts_string) do
#     # Convert RFC3339 to nanoseconds since epoch
#     # For now, use current time
#     System.system_time(:nanosecond) |> to_string()
#   end

#   defp post_to_loki(loki_url, payload) do
#     url = "#{loki_url}/loki/api/v1/push"

#     # Use Req with automatic retry for transient failures
#     case Req.post(url,
#            json: payload,
#            retry: :transient,
#            max_retries: 3,
#            retry_delay: fn attempt -> 100 * :math.pow(2, attempt) end,
#            receive_timeout: 5_000
#          ) do
#       {:ok, %{status: status}} when status in 200..299 ->
#         {:ok, :success}

#       {:ok, %{status: status, body: body}} ->
#         {:error, "HTTP #{status}: #{inspect(body)}"}

#       {:error, reason} ->
#         {:error, inspect(reason)}
#     end
#   rescue
#     e ->
#       {:error, Exception.message(e)}
#   end
# end
