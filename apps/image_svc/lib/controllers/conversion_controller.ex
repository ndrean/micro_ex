defmodule ConversionController do
  @moduledoc """
  Handles image conversion requests.

  ## Flow
  1. Receives protobuf ImageConversionRequest via HTTP
  2. Fetches the original image from the provided URL
  3. Converts image to PDF using ImageConverter
  4. Stores PDF in MinIO via user_svc
  5. Notifies user_svc of completion
  6. Responds to caller (job_svc worker)

  ## Architecture
  This controller orchestrates the conversion workflow by delegating to:
  - `ImageConverter` - Image processing
  - `UserSvcClient` - HTTP calls to user_svc
  - `ConversionOptions` - Request parameter normalization
  - `ResponseBuilder` - Protobuf response construction
  """

  use ImageSvcWeb, :controller
  use OpenApiSpex.ControllerSpecs

  require Logger

  alias ImageSvc.Schemas.{ImageConversionRequestSchema, ImageConversionResponseSchema}

  @doc """
  Handles POST /image_svc/ConvertImage endpoint.

  Processes an image conversion request from the job worker.
  """
  operation(:convert,
    summary: "Convert image to PDF",
    description: """
    Converts a PNG or JPEG image to PDF format with configurable quality settings.

    **Workflow:**
    1. Fetches image from provided URL
    2. Converts to PDF using ImageMagick (multi-threaded)
    3. Stores PDF in MinIO via user_svc
    4. Returns acknowledgment with image metadata
    """,
    request_body:
      {"Image conversion request", "application/x-protobuf", ImageConversionRequestSchema},
    responses: [
      ok: {"Conversion successful", "application/x-protobuf", ImageConversionResponseSchema},
      internal_server_error:
        {"Conversion failed", "application/x-protobuf", ImageConversionResponseSchema}
    ]
  )

  def convert(conn, _) do
    with {:ok, request, new_conn} <- decode_request(conn),
         {:ok, image_binary} <- fetch_image(request.image_url),
         {:ok, image_info} <- ImageMagick.get_image_info(image_binary),
         {:ok, bucket, key, output_size} <- perform_conversion(request, image_binary) do
      # Build MinIO URL for the PDF
      pdf_url = build_s3_url(bucket, key)

      response_binary =
        ImageSvc.ResponseBuilder.build_ack_response(
          image_info,
          output_size,
          pdf_url,
          # storage_id is the S3 key
          key,
          # original_storage_id from the request
          request.storage_id,
          # user_email from the request
          request.user_email
        )

      new_conn
      |> put_resp_content_type("application/protobuf")
      |> send_resp(200, response_binary)
    else
      {:error, reason, _} ->
        Logger.error("[Image][ConversionController] Error: #{inspect(reason)}")
        return_err(conn, inspect(reason))

      {:error, reason} ->
        Logger.error("[Image][ConversionController] Error: #{inspect(reason)}")
        return_err(conn, inspect(reason))
    end
  end

  # Request processing

  @spec decode_request(Plug.Conn.t()) ::
          {:ok, Mcsv.V2.ImageConversionRequest.t(), Plug.Conn.t()}
          | {:error, :decode_error}
  defp decode_request(conn) do
    with {:ok, binary_body, new_conn} <- Plug.Conn.read_body(conn),
         {:ok, request} <- maybe_decode_request(binary_body) do
      {:ok, request, new_conn}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Attempts to decode the binary body into an EmailRequest protobuf.
  ## Parameters
    - binary_body: The raw binary body from the HTTP request.
  ## Returns
    - {:ok, %Mcsv.V2.PdfReadyNotification{}} on success
    - {:error, :decode_error} on failure

      iex> DeliveryController.maybe_decode_email_request(1)
      {:error, :decode_error}
  r
  """

  @spec maybe_decode_request(binary()) ::
          {:ok, Mcsv.V2.ImageConversionRequest.t()} | {:error, :decode_error}
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

  @spec fetch_image(String.t()) ::
          {:ok, binary()} | {:error, :fetch_failed, any()}
  defp fetch_image(image_url) do
    Logger.info("[Image][ConversionController] Fetching image: #{image_url}")

    case Req.get(image_url) do
      {:ok, %{status: 200, body: image_binary}} ->
        Logger.info("[Image][ConversionController] Fetched #{byte_size(image_binary)} bytes")
        {:ok, image_binary}

      {:ok, %{status: status}} ->
        Logger.error("[Image][ConversionController] Failed to fetch image: HTTP #{status}")
        {:error, :fetch_failed, status}

      {:error, reason} ->
        Logger.error("[Image][ConversionController] Failed to fetch image: #{inspect(reason)}")
        {:error, :fetch_failed, reason}
    end
  end

  defp bucket do
    Application.get_env(:image_svc, :image_bucket, "msvc-images")
  end

  @spec build_s3_url(String.t(), String.t()) :: String.t()
  defp build_s3_url(bucket, key) do
    # Get MinIO endpoint from config
    s3_endpoint = Application.get_env(:ex_aws, :s3)[:host] || "localhost"
    s3_port = Application.get_env(:ex_aws, :s3)[:port] || 9000
    s3_scheme = Application.get_env(:ex_aws, :s3)[:scheme] || "http://"

    "#{s3_scheme}#{s3_endpoint}:#{s3_port}/#{bucket}/#{key}"
  end

  # Conversion workflow

  @spec perform_conversion(
          Mcsv.V2.ImageConversionRequest.t(),
          binary()
        ) :: {:ok, String.t(), String.t(), non_neg_integer()} | {:error, :conversion_failed}
  defp perform_conversion(request, image_binary) do
    opts =
      ImageSvc.ConversionOptions.build(
        request.input_format,
        request.pdf_quality,
        request.strip_metadata,
        request.max_width,
        request.max_height
      )

    with {:ok, pdf_binary} <-
           ImageSvc.ParallelConverterStream.convert_to_pdf(image_binary, opts),
         {:ok, %{bucket: bucket, key: key, size: size}} <-
           upload_binary_to_s3(pdf_binary, bucket()) do
      # Note: Client is no more notified. Return data to job_svc.
      Logger.info("[Image][ConversionController] Conversion complete: #{bucket}/#{key}")

      {:ok, bucket, key, size}
    else
      _ ->
        {:error, :conversion_failed}
    end
  end

  @spec upload_binary_to_s3(binary(), String.t()) ::
          {:ok, %{bucket: String.t(), key: String.t(), size: non_neg_integer()}}
          | {:error, any()}
  defp upload_binary_to_s3(pdf_binary, bucket) do
    key = generate_storage_id()
    # Upload to S3
    ExAws.S3.put_object(bucket, key, pdf_binary, content_type: "application/pdf")
    |> ExAws.request()
    |> case do
      {:ok, _} ->
        {:ok, %{bucket: bucket, key: key, size: byte_size(pdf_binary)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Error handlers

  defp return_err(conn, msg) do
    response_binary =
      ImageSvc.ResponseBuilder.build_failure_response(msg)

    conn
    |> put_resp_content_type("application/protobuf")
    |> send_resp(500, response_binary)
  end

  defp generate_storage_id() do
    timestamp = System.system_time(:microsecond)
    random = :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
    "#{timestamp}_#{random}.pdf"
  end

  # defp handle_fetch_error(conn, status) do
  #   response_binary =
  #     ResponseBuilder.build_failure_response("Failed to fetch image: HTTP #{status}")

  #   conn
  #   |> put_resp_content_type("application/protobuf")
  #   |> send_resp(500, response_binary)
  # end

  # # Notify user_svc of failure (for cleanup)
  # # We don't have request context here, so this is best effort
  # defp handle_conversion_error(conn, reason) do
  #   Logger.warning("[ConversionController] Skipping failure notification - no storage_id context")

  #   response_binary =
  #     ResponseBuilder.build_failure_response(reason)

  #   conn
  #   |> put_resp_content_type("application/protobuf")
  #   |> send_resp(500, response_binary)
  # end

  # defp handle_storage_error(conn, reason) do
  #   response_binary =
  #     ResponseBuilder.build_failure_response("Storage failed: #{inspect(reason)}")

  #   conn
  #   |> put_resp_content_type("application/protobuf")
  #   |> send_resp(500, response_binary)
  # end
end
