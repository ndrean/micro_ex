defmodule EmailNotificationController do
  @moduledoc """
  Receives email delivery notifications from email_svc and forwards them to user_svc.

  Flow:
  1. email_svc calls this endpoint after sending an email
  2. We decode the EmailResponse to log the status
  3. Forward the notification to user_svc
  4. Return 204 No Content
  """

  use JobServiceWeb, :controller
  require Logger
  import Plug.Conn

  alias Clients.UserSvcClient

  def notify(conn, _) do
    with {:ok, _response, binary_body, new_conn} <- decode_response(conn),
         {:ok, _} <- UserSvcClient.notify_email_sent(binary_body) do
      Logger.info("[Job][EmailNotificationController] Notification forwarded successfully")
      send_resp(new_conn, 204, "")
    else
      {:error, reason} ->
        Logger.error("[Job][EmailNotificationController] Failed: #{inspect(reason)}")
        send_resp(conn, 204, "")
    end
  end

  # Request processing

  @spec decode_response(Plug.Conn.t()) ::
          {:ok, Mcsv.EmailResponse.t(), binary(), Plug.Conn.t()} | {:error, any()}
  defp decode_response(conn) do
    {:ok, binary_body, new_conn} = read_body(conn)
    response = Mcsv.EmailResponse.decode(binary_body)

    Logger.info(
      "[Job][EmailNotificationController] Email delivery status: #{response.success}, message: #{response.message}"
    )

    {:ok, response, binary_body, new_conn}
  end
end
