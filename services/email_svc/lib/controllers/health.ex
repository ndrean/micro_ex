defmodule HealthController do
  use EmailServiceWeb, :controller

  @moduledoc false

  @doc """
  Health check endpoint for load balancers.
  """
  def check(conn, _params) do
    send_resp(conn, 200, "OK")
  end
end
