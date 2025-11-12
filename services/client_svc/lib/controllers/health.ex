defmodule HealthController do
  use ClientServiceWeb, :controller

  @moduledoc false

  def check(conn, _params) do
    send_resp(conn, 200, "OK")
  end
end
