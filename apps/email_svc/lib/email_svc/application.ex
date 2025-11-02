defmodule EmailApp do
  use Application

  @moduledoc """
  Entry point
  """

  require Logger

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:email_svc, :port, 8083)
    Logger.info("Starting EMAIL Server on port #{port}")

    children = [
      EmailSvc.Metrics,
      {Bandit, plug: EmailRouter, port: 8083}

      # Start the Oban job processing system
    ]

    opts = [strategy: :one_for_one, name: JobSvc.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
