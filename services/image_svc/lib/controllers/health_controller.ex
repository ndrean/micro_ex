defmodule HealthController do
  @moduledoc """
  Health check endpoint for load balancers and orchestration.
  """

  use ImageSvcWeb, :controller

  def check(conn, _params) do
    send_resp(conn, 200, "OK")
  end
end
