defmodule ClientApp do
  use Application

  @moduledoc """
  Entry point
  """

  def start(_type, _args) do
    IO.puts("Starting client_server 4000")

    children = [
      # ClientTelem.Telemetry,
      {Bandit, plug: ClientRouter, port: 4000}
    ]

    opts = [strategy: :one_for_one, name: ClientSvc.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
