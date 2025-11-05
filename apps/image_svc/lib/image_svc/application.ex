defmodule ImageSvc.Application do
  @moduledoc """
  Image Service Application

  Responsible for image processing operations (PNG to PDF conversion, etc.)
  Receives requests via HTTP and processes them using ImageMagick.
  """

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    # Set service name in all logs
    Logger.metadata(service: "image_svc")

    port = Application.get_env(:image_svc, :port, 8084)
    Logger.info("Starting IMAGE SERVICE on port #{port}")

    children = [
      # PromEx metrics
      ImageSvc.PromEx,
      # Prometheus metrics exporter (port 9568)
      ImageSvc.Metrics,
      # HTTP server (port 8084)
      {Bandit, plug: ImageSvc.Router, port: port}
    ]

    opts = [strategy: :one_for_one, name: ImageSvc.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
