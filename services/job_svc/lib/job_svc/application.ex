defmodule JobService.Application do
  use Application

  @moduledoc """
  Responsible for managing background job processing tasks.
  Uses Oban for job queue management and processing.
  """

  require Logger

  @impl true
  def start(_type, _args) do
    JobService.Release.migrate()

    # Enable OpenTelemetry instrumentation for Ecto
    OpentelemetryEcto.setup([:job_svc, :ecto_repos])

    # OpentelemetryOban.setup(trace: [:jobs])  # Disabled: dependency conflict with opentelemetry_req

    # PromEx must start before Repo to capture Ecto init events
    children = [
      JobService.PromEx,
      JobServiceWeb.Telemetry,
      JobService.Repo,
      {Oban, Application.fetch_env!(:job_svc, Oban)},
      JobServiceWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: JobService.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
