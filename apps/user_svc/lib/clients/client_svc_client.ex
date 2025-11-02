defmodule Clients.ClientSvcClient do
  @moduledoc """
  HTTP client for communicating with client_svc.

  Handles async notifications to clients about PDF readiness.
  """

  require Logger

  @base_url Application.compile_env(:user_svc, :client_svc_base_url)
  @endpoints Application.compile_env(:user_svc, :client_svc_endpoints)

  @doc """
  Notifies the client that their PDF is ready.

  Sends an async notification (non-blocking) to client_svc.

  ## Parameters
  - `user_email`: User's email address
  - `storage_id`: The PDF's storage ID in MinIO
  - `presigned_url`: Temporary download URL
  - `size`: File size in bytes
  """
  def notify_pdf_ready(user_email, storage_id, presigned_url, size) do
    Logger.info("[ClientSvcClient] Notifying client that PDF is ready for #{user_email}")

    notification =
      %Mcsv.PdfReadyNotification{
        user_email: user_email,
        storage_id: storage_id,
        presigned_url: presigned_url,
        size: size,
        message: "Your PDF is ready! Click the URL to view."
      }
      |> Mcsv.PdfReadyNotification.encode()

    # Send async notification (don't block on response)
    Task.start(fn ->
      case post(@base_url, @endpoints.pdf_ready, notification) do
        {:ok, %{status: 204}} ->
          Logger.info("[ClientSvcClient] Client notified successfully")

        {:ok, %{status: status}} ->
          Logger.warning("[ClientSvcClient] Client notification returned status #{status}")

        {:error, reason} ->
          Logger.warning("[ClientSvcClient] Client notification failed: #{inspect(reason)}")
      end
    end)

    :ok
  end

  @doc """
  Forwards email delivery notification to client_svc.

  ## Parameters
  - `message`: The notification message to forward

  ## Returns
  - `:ok` on success
  - `{:error, reason}` on failure
  """
  def receive_notification(message) do
    Logger.info("[ClientSvcClient] Forwarding email notification")

    case post(@base_url, @endpoints.receive_notification, message) do
      {:ok, %{status: 204}} ->
        Logger.info("[ClientSvcClient] Notification forwarded successfully")
        :ok

      {:ok, %{status: status}} ->
        Logger.warning("[ClientSvcClient] Notification returned status #{status}")
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        Logger.error("[ClientSvcClient] Notification failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private HTTP helper

  defp post(base, path, body, opts \\ []) do
    receive_timeout = Keyword.get(opts, :receive_timeout, 5_000)

    case Req.post(
           Req.new(base_url: base),
           url: path,
           body: body,
           headers: [{"content-type", "application/protobuf"}],
           receive_timeout: receive_timeout
         ) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end
end
