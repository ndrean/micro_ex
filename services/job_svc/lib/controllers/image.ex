defmodule ImageController do
  use JobServiceWeb, :controller
  require Logger
  @moduledoc false

  @doc """
  Enqueue image conversion job.

  Receives ImageConversionRequest protobuf, enqueues Oban job, returns acknowledgment.
  """

  def convert(conn, _) do
    with {:read_body, {:ok, binary_body, new_conn}} <-
           {:read_body, Plug.Conn.read_body(conn)},
         {:decode, {:ok, request}} <-
           {:decode, maybe_decode_request(binary_body)},
         {:enqueue, {:ok, %Oban.Job{id: oban_job_id} = _job}} <-
           {:enqueue, enqueue_conversion_job(request)} do
      Logger.info("[Job][ImageController] Image job enqueued #{oban_job_id}")

      # Return acknowledgment
      response_binary =
        %Mcsv.V2.UserResponse{
          ok: true,
          message: "[Job][ImageController] Image job enqueued (oban_job_id: #{oban_job_id})"
        }
        |> Mcsv.V2.UserResponse.encode()

      new_conn
      |> put_resp_content_type("application/protobuf")
      |> send_resp(200, response_binary)
    else
      {step, {:error, reason}} ->
        handle_error(conn, step, reason)
    end
  end

  defp handle_error(conn, step, reason) do
    Logger.error("[Job][ImageController] Failed #{step}: #{inspect(reason)}")

    response_binary =
      %Mcsv.V2.UserResponse{
        ok: false,
        message: "[Job][ImageController] Failed #{step}: #{inspect(reason)}"
      }
      |> Mcsv.V2.UserResponse.encode()

    conn
    |> put_resp_content_type("application/protobuf")
    |> send_resp(500, response_binary)
  end

  # @spec convert(Plug.Conn.t()) :: Plug.Conn.t()
  # def convert(conn) do
  #   {:ok, binary_body, new_conn} = Plug.Conn.read_body(conn)

  #   # Enqueue Oban job
  #   binary_body
  #   |> Mcsv.V2.ImageConversionRequest.decode()
  #   |> enqueue_conversion_job()
  #   |> case do
  #     {:ok, %Oban.Job{id: oban_job_id}} ->
  #       Logger.info("[Job][ImageController] Image conversion job #{oban_job_id}")

  #       # Return acknowledgment
  #       response_binary =
  #         %Mcsv.V2.UserResponse{
  #           ok: true,
  #           message:
  #             "[Job][ImageController] Image conversion job enqueued (oban_job_id: #{oban_job_id})"
  #         }
  #         |> Mcsv.V2.UserResponse.encode()

  #       new_conn
  #       |> put_resp_content_type("application/protobuf")
  #       |> send_resp(200, response_binary)

  #     {:error, reason} ->
  #       Logger.error(
  #         "[[Job]ImageController] Failed to enqueue image conversion job: #{inspect(reason)}"
  #       )

  #       response_binary =
  #         %Mcsv.V2.UserResponse{
  #           ok: false,
  #           message: "[Job][ImageController] Failed to enqueue job: #{inspect(reason)}"
  #         }
  #         |> Mcsv.V2.UserResponse.encode()

  #       conn
  #       |> put_resp_content_type("application/protobuf")
  #       |> send_resp(500, response_binary)
  #   end
  # end

  def maybe_decode_request(binary_body) do
    try do
      %Mcsv.V2.ImageConversionRequest{} =
        resp = Mcsv.V2.ImageConversionRequest.decode(binary_body)

      {:ok, resp}
    catch
      :error, reason ->
        Logger.error("[Image][ConversionController] Protobuf decode error: #{inspect(reason)}")
        {:error, :decode_error}
    end
  end

  @spec enqueue_conversion_job(Mcsv.V2.ImageConversionRequest.t()) ::
          {:ok, Oban.Job.t()} | {:error, any()}
  defp enqueue_conversion_job(%Mcsv.V2.ImageConversionRequest{} = job_args) do
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
