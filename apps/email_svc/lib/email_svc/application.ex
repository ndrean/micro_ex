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
      EmailServiceWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: EmailService.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
