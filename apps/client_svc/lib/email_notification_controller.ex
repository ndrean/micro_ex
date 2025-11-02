defmodule EmailNotificationController do

  require Logger

  def receive(conn) do
    {:ok, binary_body, conn} = Plug.Conn.read_body(conn)
    Logger.info("Received email notification: #{inspect(binary_body)}")

    conn
    |> Plug.Conn.send_resp(204, "")
  end
end
