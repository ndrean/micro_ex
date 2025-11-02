defmodule ImageSvc.ConversionController do
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

  use OpenApiSpex.ControllerSpecs

  require Logger
  import Plug.Conn

  alias ImageSvc.{UserSvcClient, ConversionOptions, ResponseBuilder}
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
    2. Converts to PDF using ImageMagick
    3. Stores PDF in MinIO via user_svc
    4. Returns acknowledgment with image metadata

    **Note:** Client notification is handled automatically by user_svc after storage.
    """,
    request_body:
      {"Image conversion request", "application/x-protobuf", ImageConversionRequestSchema},
    responses: [
      ok: {"Conversion successful", "application/x-protobuf", ImageConversionResponseSchema},
      internal_server_error:
        {"Conversion failed", "application/x-protobuf", ImageConversionResponseSchema}
    ]
  )

  def convert(conn) do
    with {:ok, request} <- decode_request(conn),
         {:ok, image_binary} <- fetch_image(request.image_url),
         {:ok, image_info} <- get_image_info(image_binary),
         {:ok, output_size} <- perform_conversion(request, image_binary) do
      response_binary = ResponseBuilder.build_ack_response(image_info, output_size)

      conn
      |> put_resp_content_type("application/protobuf")
      |> send_resp(200, response_binary)
    else
      {:error, :fetch_failed, status} ->
        handle_fetch_error(conn, status)

      {:error, :conversion_failed, reason} ->
        handle_conversion_error(conn, reason)

      {:error, :storage_failed, reason} ->
        handle_storage_error(conn, reason)
    end
  end

  # Request processing

  defp decode_request(conn) do
    case Plug.Conn.read_body(conn) do
      {:ok, binary_body, _conn} ->
        {:ok, Mcsv.ImageConversionRequest.decode(binary_body)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_image(image_url) do
    Logger.info("[ConversionController] Fetching image from URL: #{image_url}")

    case Req.get(image_url) do
      {:ok, %{status: 200, body: image_binary}} ->
        Logger.info("[ConversionController] Fetched #{byte_size(image_binary)} bytes")
        {:ok, image_binary}

      {:ok, %{status: status}} ->
        Logger.error("[ConversionController] Failed to fetch image: HTTP #{status}")
        {:error, :fetch_failed, status}

      {:error, reason} ->
        Logger.error("[ConversionController] Failed to fetch image: #{inspect(reason)}")
        {:error, :fetch_failed, reason}
    end
  end

  defp get_image_info(image_binary) do
    case ImageConverter.get_image_info(image_binary) do
      {:ok, info} ->
        Logger.info(
          "[ConversionController] Image: #{info.format} #{info.width}x#{info.height}, #{info.size} bytes"
        )

        {:ok, info}

      {:error, reason} ->
        {:error, :image_info_failed, reason}
    end
  end

  # Conversion workflow

  defp perform_conversion(request, image_binary) do
    opts =
      ConversionOptions.build(
        request.input_format,
        request.pdf_quality,
        request.strip_metadata,
        request.max_width,
        request.max_height
      )

    with {:ok, pdf_binary} <-
           convert_to_pdf(image_binary, opts),
         {:ok, _store_response} <-
           store_pdf(request, pdf_binary) do
      # Note: Client is already notified by user_svc/StoreImageController
      # No need for separate notification here
      Logger.info("[ConversionController] Conversion complete - client notified by user_svc")
      {:ok, byte_size(pdf_binary)}
    else
      error ->
        # Error is already in the correct format from helper functions
        error
    end
  end

  defp convert_to_pdf(image_binary, opts) do
    case ImageConverter.convert(image_binary, opts) do
      {:ok, pdf_binary} ->
        Logger.info("[ConversionController] Converted to PDF: #{byte_size(pdf_binary)} bytes")
        {:ok, pdf_binary}

      {:error, reason} ->
        Logger.error("[ConversionController] Conversion failed: #{reason}")
        {:error, :conversion_failed, reason}
    end
  end

  defp store_pdf(request, pdf_binary) do
    case UserSvcClient.store_pdf(
           pdf_binary,
           request.user_id,
           request.storage_id,
           request.user_email
         ) do
      {:ok, %{success: true} = store_response} ->
        Logger.info(
          "[ConversionController] PDF stored successfully: #{store_response.storage_id}"
        )

        {:ok, store_response}

      {:ok, %{success: false, message: message}} ->
        Logger.error("[ConversionController] Storage failed: #{message}")
        {:error, :storage_failed, message}

      {:error, reason} ->
        Logger.error("[ConversionController] Failed to store PDF: #{inspect(reason)}")
        {:error, :storage_failed, reason}
    end
  end

  # Error handlers

  defp handle_fetch_error(conn, status) do
    response_binary =
      ResponseBuilder.build_failure_response("Failed to fetch image: HTTP #{status}")

    conn
    |> put_resp_content_type("application/protobuf")
    |> send_resp(500, response_binary)
  end

  defp handle_conversion_error(conn, reason) do
    # Notify user_svc of failure (for cleanup)
    # We don't have request context here, so this is best effort
    Logger.warning("[ConversionController] Skipping failure notification - no storage_id context")

    response_binary = ResponseBuilder.build_failure_response(reason)

    conn
    |> put_resp_content_type("application/protobuf")
    |> send_resp(500, response_binary)
  end

  defp handle_storage_error(conn, reason) do
    response_binary = ResponseBuilder.build_failure_response("Storage failed: #{inspect(reason)}")

    conn
    |> put_resp_content_type("application/protobuf")
    |> send_resp(500, response_binary)
  end
end
