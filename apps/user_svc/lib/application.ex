defmodule UserApp do
  use Application
  require OpenTelemetry.Tracer

  @moduledoc """
  Entry point
  """

  @impl true
  def start(_type, _args) do
    IO.puts("Starting user_server 8081")

    children = [
      {Bandit, plug: UserRouter, port: 8081}
    ]

    opts = [strategy: :one_for_one, name: UserSvc.Supervisor]
    Supervisor.start_link(children, opts)

    # :ok =
    #   :openTelemetry.exporter(
    #     exporter: :jaeger,
    #     host: "localhost",
    #     port: 4318
    #   )
  end
end
