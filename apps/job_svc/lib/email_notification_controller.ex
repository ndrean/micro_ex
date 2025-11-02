defmodule EmailNotificationController do
  @moduledoc """
  Receives email delivery notifications from email_svc and forwards them to user_svc.

  Flow:
  1. email_svc calls this endpoint after sending an email
  2. We decode the EmailResponse to log the status
  3. Forward the notification to user_svc
  4. Return 204 No Content
  """

  require Logger
  import Plug.Conn

  alias Clients.UserSvcClient

  @spec notify(Plug.Conn.t()) :: Plug.Conn.t()
  def notify(conn) do
    with {:ok, _response, binary_body} <- decode_response(conn),
         {:ok, _} <- UserSvcClient.notify_email_sent(binary_body) do
      Logger.info("[EmailNotificationController] Notification forwarded successfully")
      send_resp(conn, 204, "")
    else
      {:error, reason} ->
        Logger.error("[EmailNotificationController] Failed: #{inspect(reason)}")
        send_resp(conn, 204, "")
    end
  end

  # Request processing

  @spec decode_response(Plug.Conn.t()) ::
          {:ok, Mcsv.EmailResponse.t(), binary()} | {:error, any()}
  defp decode_response(conn) do
    {:ok, binary_body, _conn} = read_body(conn)
    response = Mcsv.EmailResponse.decode(binary_body)

    Logger.info(
      "[EmailNotificationController] Email delivery status: #{response.success}, message: #{response.message}"
    )

    {:ok, response, binary_body}
  end
end
