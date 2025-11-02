defmodule ForwardEmailNotificationController do
  @moduledoc """
  Forwards email delivery notifications from email_svc to client_svc.

  Flow:
  1. Receives EmailResponse from email_svc
  2. If successful, forwards message to client_svc
  3. Always returns 204 No Content (fire-and-forget)
  """

  require Logger
  import Plug.Conn

  alias Clients.ClientSvcClient

  def forward(conn) do
    with {:ok, response} <- decode_response(conn),
         :ok <- maybe_forward_to_client(response) do

      conn
      |> send_resp(204, "")
    else
      {:error, reason} ->
        Logger.error("[ForwardEmailNotificationController] Failed: #{inspect(reason)}")
        conn
        |> send_resp(204, "")
    end
  end

  # Request processing

  defp decode_response(conn) do
    {:ok, binary_body, _conn} = read_body(conn)
    response = Mcsv.EmailResponse.decode(binary_body)

    Logger.info(
      "[ForwardEmailNotificationController] Email delivery status: #{response.success}"
    )

    {:ok, response}
  end

  defp maybe_forward_to_client(response) do
    if response.success do
      Logger.info("[ForwardEmailNotificationController] Forwarding success to client_svc")
      ClientSvcClient.receive_notification(response.message)
    else
      Logger.warning("[ForwardEmailNotificationController] Email delivery failed: #{response.message}")
      :ok
    end
  end
end
