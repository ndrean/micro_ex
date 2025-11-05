defmodule JobApp do
  use Application
  @moduledoc false

  require Logger

  @impl true
  def start(_type, _args) do
    JobSvc.Release.migrate()
    port = Application.get_env(:job_svc, :port, 8082)
    Logger.info("Starting JOB SERVER on port #{port}")

    # Enable OpenTelemetry instrumentation
    OpentelemetryEcto.setup([:job_svc, :ecto_repos])

    # OpentelemetryOban.setup(trace: [:jobs])  # Disabled: dependency conflict with opentelemetry_req

    children = [
      # PromEx must start before Repo to capture Ecto init events
      JobSvc.PromEx,
      JobService.Repo,
      JobService.Metrics,
      {Bandit, plug: JobRouter, port: port},
      {Oban, Application.fetch_env!(:job_svc, Oban)}
    ]

    opts = [strategy: :one_for_one, name: JobSvc.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
