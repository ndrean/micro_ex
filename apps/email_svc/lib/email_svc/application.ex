defmodule EmailService.Application do
  use Application

  @moduledoc false

  require Logger

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:email_svc, :port, 8083)
    Logger.info("Starting EMAIL Server on port #{port}")

    children = [
      EmailService.PromEx,
      EmailServiceWeb.Telemetry,
      {Cluster.Supervisor, [topologies(), [name: EmailService.Application.ClusterSupervisor]]},
      EmailServiceWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: EmailService.Supervisor]
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
