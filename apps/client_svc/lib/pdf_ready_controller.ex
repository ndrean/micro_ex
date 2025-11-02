defmodule PdfReadyController do
  @moduledoc """
  Handles async notifications when PDFs are ready for viewing.

  This controller receives callbacks from user_svc after image-to-PDF
  conversion completes and the PDF is stored in MinIO.
  """

  require Logger
  import Plug.Conn

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
  def receive(conn) do
    {:ok, binary_body, conn} = read_body(conn)

    %Mcsv.PdfReadyNotification{
      user_email: user_email,
      presigned_url: presigned_url,
      size: size,
      message: message
    } = Mcsv.PdfReadyNotification.decode(binary_body)

    Logger.info("User:  #{user_email}, #{message}")
    Logger.info("📄 VIEW YOUR PDF: #{presigned_url}")

    send_resp(conn, 204, "")
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 2)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024), 2)} MB"
end
