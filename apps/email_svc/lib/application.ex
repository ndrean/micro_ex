defmodule EmailApp do
  use Application
  @moduledoc"""
  Entry point
  """

  @impl true
  def start(_type, _args) do
    IO.puts("Starting email_server 8083")
    children = [
      {Bandit, plug: EmailRouter, port: 8083},

      # Start the Oban job processing system

    ]

    opts = [strategy: :one_for_one, name: JobSvc.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
