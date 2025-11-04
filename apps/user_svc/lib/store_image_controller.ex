defmodule StoreImageController do
  @moduledoc """
  Handles storage of images and PDFs to MinIO.

  Provides a centralized endpoint for other services (like image_svc)
  to upload binary data and receive presigned URLs.

  For PDF conversions, this controller also notifies the client when
  the PDF is ready via async callback.
  """

  require Logger
  import Plug.Conn

  alias Clients.ClientSvcClient

  @doc """
  POST /user_svc/StoreImage

  Receives binary image/PDF data, stores in MinIO, returns presigned URL.

  ## Request (Protobuf: StoreImageRequest)
    - image_data: Binary data
    - user_id: User identifier
    - format: File format ("png", "pdf", "jpeg")
    - original_storage_id: Optional reference to original image (unused)
    - user_email: User email (REQUIRED for PDF format)

  ## Response (Protobuf: StoreImageResponse)
    - success: Boolean
    - message: Status message
    - storage_id: MinIO object key
    - presigned_url: Temporary download URL (valid 1 hour)
    - size: File size in bytes
  """
  def store(conn) do
    with {:ok, request, conn} <- decode_request(conn),
         :ok <- validate_request(request),
         {:ok, storage_id, presigned_url} <- store_image(request),
         :ok <- maybe_notify_client(request, storage_id, presigned_url) do
      size = byte_size(request.image_data)

      response_binary =
        ProtobufHelpers.build_store_success(
          request.format,
          storage_id,
          presigned_url,
          size
        )

      conn
      |> put_resp_content_type("application/protobuf")
      |> send_resp(200, response_binary)
    else
      {:error, :invalid_pdf_request} ->
        send_error(conn, 400, "PDF format requires user_email")

      {:error, reason} ->
        Logger.error("[StoreImageController] Failed: #{inspect(reason)}")
        response_binary = ProtobufHelpers.build_store_failure(reason)

        conn
        |> put_resp_content_type("application/protobuf")
        |> send_resp(500, response_binary)
    end
  end

  # Request processing

  defp decode_request(conn) do
    {:ok, binary_body, new_conn} = read_body(conn)

    request = Mcsv.StoreImageRequest.decode(binary_body)

    Logger.info(
      "[StoreImageController] Storing #{request.format} for user #{request.user_id} " <>
        "(#{byte_size(request.image_data)} bytes)"
    )

    {:ok, request, new_conn}
  end

  defp validate_request(request) do
    # PDF format requires user_email for notification
    if request.format == "pdf" && (is_nil(request.user_email) || request.user_email == "") do
      {:error, :invalid_pdf_request}
    else
      :ok
    end
  end

  defp store_image(request) do
    case ImageStorage.store(request.image_data, request.user_id, request.format) do
      {:ok, storage_id} ->
        case ImageStorage.get_presigned_url(storage_id) do
          {:ok, presigned_url} ->
            Logger.info("[StoreImageController] Success: #{storage_id}")
            Logger.debug("[StoreImageController] Presigned URL: #{presigned_url}")
            {:ok, storage_id, presigned_url}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_notify_client(request, storage_id, presigned_url) do
    # Only notify for PDFs (validation ensures user_email exists for PDFs)
    if request.format == "pdf" do
      size = byte_size(request.image_data)
      ClientSvcClient.notify_pdf_ready(request.user_email, storage_id, presigned_url, size)
    end

    :ok
  end

  defp send_error(conn, status, message) do
    Logger.warning("[StoreImageController] #{message}")
    response_binary = ProtobufHelpers.build_store_failure(message)

    conn
    |> put_resp_content_type("application/protobuf")
    |> send_resp(status, response_binary)
  end
end
