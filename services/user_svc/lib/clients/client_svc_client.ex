defmodule Clients.ClientSvcClient do
  @moduledoc """
  HTTP client for communicating with client_svc.

  Handles async notifications to clients about PDF readiness.
  """

  require Logger

  # Runtime config - reads from runtime.exs via environment variables
  defp client_svc_base_url, do: Application.get_env(:user_svc, :client_svc_base_url)
  defp client_svc_endpoints, do: Application.get_env(:user_svc, :client_svc_endpoints)

  @doc """
  Notifies client_svc that image conversion is complete.

  Transforms ImageConversionResponse into PdfReadyNotification and forwards to client_svc.

  ## Parameters
  - `image_conversion_response`: Decoded Mcsv.ImageConversionResponse struct

  ## Returns
  - `:ok` on success
  - `{:error, reason}` on failure
  """
  def notify_image_converted(%Mcsv.V2.ImageConversionResponse{} = response) do
    Logger.info(
      "[User][ClientSvcClient] Notifying client about PDF ready for storage_id=#{response.storage_id}"
    )

    # Transform ImageConversionResponse -> PdfReadyNotification
    notification =
      %Mcsv.V2.PdfReadyNotification{
        user_email: response.user_email,
        storage_id: response.storage_id,
        presigned_url: response.pdf_url,
        # Use pdf_url as presigned_url (already contains full MinIO URL)
        size: response.output_size,
        message:
          "Your PDF is ready! Size: #{response.width}x#{response.height}, #{format_size(response.output_size)}"
      }
      |> Mcsv.V2.PdfReadyNotification.encode()

    case post(client_svc_base_url(), client_svc_endpoints().pdf_ready, notification) do
      {:ok, %{status: 204}} ->
        Logger.info("[User][ClientSvcClient] Client notified about PDF successfully")
        :ok

      {:ok, %{status: status}} ->
        Logger.warning("[User][ClientSvcClient] PDF notification returned status #{status}")

        {:error, "HTTP #{status}"}

      {:error, reason} ->
        Logger.warning("[User][ClientSvcClient] PDF notification failed: #{inspect(reason)}")

        {:error, reason}
    end
  end

  defp format_size(bytes) when bytes < 1024, do: "#{bytes}B"
  defp format_size(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)}KB"
  defp format_size(bytes), do: "#{Float.round(bytes / (1024 * 1024), 1)}MB"

  @doc """
  Forwards email delivery notification to client_svc.

  ## Parameters
  - `message`: The notification message to forward

  ## Returns
  - `:ok` on success
  - `{:error, reason}` on failure
  """
  def push_notification(message) do
    Logger.info("[User][ClientSvcClient] Forwarding email notification")

    case post(client_svc_base_url(), client_svc_endpoints().receive_notification, message) do
      {:ok, %{status: 204}} ->
        Logger.info("[User][ClientSvcClient] Notification forwarded successfully")
        :ok

      {:ok, %{status: status}} ->
        Logger.warning("[User][ClientSvcClient] Notification returned status #{status}")
        {:error, "[User] HTTP #{status}"}

      {:error, reason} ->
        Logger.error("[User][ClientSvcClient] Notification failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private HTTP helper

  defp post(base, path, body, opts \\ []) do
    receive_timeout = Keyword.get(opts, :receive_timeout, 5_000)

    case Req.post(
           Req.new(base_url: base)
           |> OpentelemetryReq.attach(propagate_trace_headers: true),
           url: path,
           body: body,
           headers: [{"content-type", "application/protobuf"}],
           receive_timeout: receive_timeout
         ) do
      {:ok, %Req.Response{} = response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end
end
