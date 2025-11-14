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
      {Cluster.Supervisor, [topologies(), [name: JobService.Application.ClusterSupervisor]]},
      {Oban, Application.fetch_env!(:job_svc, Oban)},
      JobServiceWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: JobService.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp topologies do
    [
      msvc_cluster: [
        strategy: Cluster.Strategy.Epmd,
        config: [
          hosts: [
            :"user_svc@user_svc.msvc_default",
            :"job_svc@job_svc.msvc_default",
            :"image_svc@image_svc.msvc_default",
            :"email_svc@email_svc.msvc_default"
          ]
        ]
      ]
    ]
  end
end
