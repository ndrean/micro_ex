defmodule ImageController do
  import Plug.Conn
  require Logger
  @moduledoc false

  @doc """
  Enqueue image conversion job.

  Receives ImageConversionRequest protobuf, enqueues Oban job, returns acknowledgment.
  """
  @spec convert(Plug.Conn.t()) :: Plug.Conn.t()
  def convert(conn) do
    {:ok, binary_body, new_conn} = Plug.Conn.read_body(conn)

    # Enqueue Oban job
    binary_body
    |> Mcsv.ImageConversionRequest.decode()
    |> enqueue_conversion_job()
    |> case do
      {:ok, %Oban.Job{id: oban_job_id}} ->
        Logger.info("[Job][ImageController] Image conversion job #{oban_job_id}")

        # Return acknowledgment
        response_binary =
          %Mcsv.UserResponse{
            ok: true,
            message:
              "[Job][ImageController] Image conversion job enqueued (oban_job_id: #{oban_job_id})"
          }
          |> Mcsv.UserResponse.encode()

        new_conn
        |> put_resp_content_type("application/protobuf")
        |> send_resp(200, response_binary)

      {:error, reason} ->
        Logger.error(
          "[[Job]ImageController] Failed to enqueue image conversion job: #{inspect(reason)}"
        )

        response_binary =
          %Mcsv.UserResponse{
            ok: false,
            message: "[Job][ImageController] Failed to enqueue job: #{inspect(reason)}"
          }
          |> Mcsv.UserResponse.encode()

        conn
        |> put_resp_content_type("application/protobuf")
        |> send_resp(500, response_binary)
    end
  end

  @spec enqueue_conversion_job(Mcsv.ImageConversionRequest.t()) ::
          {:ok, Oban.Job.t()} | {:error, any()}
  defp enqueue_conversion_job(%Mcsv.ImageConversionRequest{} = job_args) do
    # Inject OpenTelemetry trace context into job args
    trace_headers = :otel_propagator_text_map.inject([])
    trace_context = Map.new(trace_headers)

    # Build args map for Oban job (just metadata!)
    %{
      "user_id" => job_args.user_id,
      "user_email" => job_args.user_email,
      "image_url" => job_args.image_url,
      # Thread storage_id through
      "storage_id" => job_args.storage_id,
      "input_format" => job_args.input_format || "png",
      "pdf_quality" => job_args.pdf_quality || "high",
      "strip_metadata" => job_args.strip_metadata,
      "max_width" => job_args.max_width,
      "max_height" => job_args.max_height,
      "_otel_trace_context" => trace_context
    }
    |> JobService.Workers.ImageConversionWorker.new()
    |> Oban.insert()
  end
end
