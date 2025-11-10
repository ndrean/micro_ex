defmodule PdfReadyController do
  @moduledoc """
  Handles async notifications when PDFs are ready for viewing.

  This controller receives callbacks from user_svc after image-to-PDF
  conversion completes and the PDF is stored in MinIO.
  """

  use ClientServiceWeb, :controller
  require Logger

  @doc """
  POST /client_svc/PdfReady

  Receives protobuf notification when a PDF conversion is complete.

  ## Request (Protobuf: PdfReadyNotification)
    - user_email: User who initiated the conversion
    - storage_id: PDF storage ID in MinIO
    - presigned_url: Temporary URL to view/download PDF
    - size: PDF size in bytes
    - message: Human-readable status message

  ## Response (Protobuf: PdfReadyResponse)
    - ok: Boolean success indicator
    - message: Acknowledgment message
  """
  def receive(conn, _) do
    with {:ok, binary_body, conn} <-
           read_body(conn),
         {:ok,
          %Mcsv.PdfReadyNotification{
            user_email: user_email,
            presigned_url: presigned_url,
            size: size,
            message: message
          }} <-
           maybe_decode_request(binary_body) do
      handle_notification(conn, user_email, presigned_url, size, message)
    else
      {:error, :decode_error} ->
        Logger.error("[PdfReady][PdfReadyController] Failed to decode PdfReadyNotification")

        send_resp(conn, 422, "[PdfReady][PdfReadyController] Unprocessable Entity")
    end
  end

  defp handle_notification(conn, user_email, presigned_url, _size, message) do
    Logger.info("User: #{user_email}, #{message}, you can view your PDF @ \n#{presigned_url}")

    send_resp(conn, 204, "")
  end

  @doc """
  Attempts to decode the binary body into an EmailRequest protobuf.
  ## Parameters
    - binary_body: The raw binary body from the HTTP request.
  ## Returns
    - {:ok, %Mcsv.PdfReadyNotification{}} on success
    - {:error, :decode_error} on failure

      iex> DeliveryController.maybe_decode_email_request(1)
      {:error, :decode_error}
  r
  """

  def maybe_decode_request(binary_body) do
    try do
      %Mcsv.PdfReadyNotification{} =
        resp = Mcsv.PdfReadyNotification.decode(binary_body)

      {:ok, resp}
    catch
      :error, reason ->
        Logger.error("[PdfReady][PdfReadyController] Protobuf decode error: #{inspect(reason)}")
        {:error, :decode_error}
    end
  end
end
