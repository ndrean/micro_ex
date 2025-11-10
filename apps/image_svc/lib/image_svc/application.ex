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

    ImageService.Release.migrate()
    OpentelemetryEcto.setup([:image_svc, :ecto_repos])
    # OpenTelemetry.register_application_tracer(:image_svc)
    # OpentelemetryLoggerMetadata.setup()

    port = Application.get_env(:image_svc, :port, 8084)
    Logger.info("Starting IMAGE SERVICE on port #{port}")

    children = [
      # OpenTelemetry auto-instrumentation (must be first)
      ImageSvcWeb.Telemetry,
      # PromEx must start before Repo to capture Ecto init events
      ImageService.PromEx,
      # ETS metadata cache (must start before endpoint)
      # ImageSvc.MetadataCache,
      ImageService.Repo,
      # SQLite conversion cache with persistent connection
      # ImageSvc.ConversionCacheServer,
      ImageSvcWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ImageService.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
