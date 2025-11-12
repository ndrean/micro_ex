defmodule ForwardEmailNotificationController do
  @moduledoc """
  Forwards email delivery notifications from email_svc to client_svc.

  Flow:
  1. Receives EmailResponse from email_svc
  2. If successful, forwards message to client_svc
  3. Always returns 204 No Content (fire-and-forget)
  """

  use UserSvcWeb, :controller
  require Logger
  import Plug.Conn

  alias Clients.ClientSvcClient

  def forward(conn, _) do
    with {:ok, response, new_conn} <- decode_response(conn),
         :ok <- maybe_forward_to_client(response) do
      new_conn
      |> send_resp(204, "")
    else
      {:error, reason} ->
        Logger.error("[User][ForwardEmailNotificationController] Failed: #{inspect(reason)}")

        conn
        |> send_resp(422, "[User][ForwardEmailNotificationController] Failed: #{inspect(reason)}")
    end
  end

  # Request processing

  defp decode_response(conn) do
    {:ok, binary_body, conn} = read_body(conn)
    response = Mcsv.V2.EmailResponse.decode(binary_body)

    Logger.info(
      "[User][ForwardEmailNotificationController] Email delivery status: #{response.success}"
    )

    {:ok, response, conn}
  end

  defp maybe_forward_to_client(response) do
    Logger.info("[User][ForwardEmailNotificationController] Forwarding response to client_svc")
    ClientSvcClient.push_notification(response.message)
  end
end
