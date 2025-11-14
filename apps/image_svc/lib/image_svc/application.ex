defmodule ImageService.Application do
  use Application

  @moduledoc """
  Image Service Application

  Responsible for image processing operations (PNG to PDF conversion, etc.)
  Receives requests via HTTP and processes them using:
  - ImageMagick for image format detection, metadata extraction, and PDF conversion
  - Ghostscript (used internally by ImageMagick for PDF rendering)
  """

  require Logger

  @impl true
  def start(_type, _args) do
    ImageMagick.check()

    children = [
      # PromEx must start before Repo to capture Ecto init events
      ImageService.PromEx,
      # OpenTelemetry auto-instrumentation (must be first)
      ImageSvcWeb.Telemetry,
      {Cluster.Supervisor, [topologies(), [name: ImageService.Application.ClusterSupervisor]]},
      ImageSvcWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ImageService.Supervisor]
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
