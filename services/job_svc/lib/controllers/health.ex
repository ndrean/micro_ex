defmodule HealthController do
  use JobServiceWeb, :controller

  @moduledoc """
  Health check controller for liveness and readiness probes.
  """

  @doc """
  Liveness and readiness check endpoint.

  Responds with 200 OK if the service is healthy.
  """
  def check(conn, _params) do
    send_resp(conn, 200, "OK")
  end
end
