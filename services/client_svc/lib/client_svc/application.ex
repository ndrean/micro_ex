defmodule ClientService.Application do
  use Application

  @moduledoc false

  require Logger

  def start(_type, _args) do
    children = [
      # PromEx metrics
      ClientService.PromEx,
      ClientServiceWeb.Telemetry,
      ClientServiceWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ClientService.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
