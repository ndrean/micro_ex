defmodule UserApp do
  use Application
  require OpenTelemetry.Tracer

  @moduledoc """
  Entry point
  """
  require Logger

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:user_svc, :port, 8081)
    Logger.info("Starting JOB SERVER on port #{port}")

    Logger.metadata(service: "user_svc")

    children = [
      UserSvc.Metrics,
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
