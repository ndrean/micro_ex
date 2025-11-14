defmodule ClientService.Application do
  use Application

  @moduledoc false

  require Logger

  def start(_type, _args) do
    children = [
      # PromEx metrics
      ClientService.PromEx,
      ClientServiceWeb.Telemetry,
      {Cluster.Supervisor, [topologies(), [name: ClientService.Application.ClusterSupervisor]]},
      ClientServiceWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ClientService.Supervisor]
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
