defmodule EmailNotificationController do
  use ClientServiceWeb, :controller
  require Logger

  def receive(conn, _) do
    case Plug.Conn.read_body(conn) do
      {:ok, binary_body, conn} ->
        Logger.info(
          "[Client][EmailNotificationController] Received Email notification: #{inspect(binary_body)}"
        )

        conn
        |> Plug.Conn.send_resp(204, "")

      {:error, reason} ->
        Logger.error("[Client][EmailNotificationController] Failed: #{inspect(reason)}")

        conn
        |> Plug.Conn.send_resp(422, "[Client][EmailNotificationController]  Unprocessable")
    end
  end
end
