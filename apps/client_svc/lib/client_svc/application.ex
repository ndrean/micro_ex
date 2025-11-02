defmodule ClientApp do
  use Application

  @moduledoc """
  Entry point
  """

  require Logger

  def start(_type, _args) do
    port = Application.get_env(:client_svc, :port, 4000)
    Logger.info("Starting CLIENT Server on port #{port}")

    children = [
      ClientSvc.Metrics,
      {Bandit, plug: ClientRouter, port: 4000}
    ]

    opts = [strategy: :one_for_one, name: ClientSvc.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
