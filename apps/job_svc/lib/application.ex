defmodule JobApp do
  use Application
  @moduledoc false

  @impl true
  def start(_type, _args) do
    IO.puts("Starting job_server 8082")

    OpentelemetryEcto.setup([:job_svc, :ecto_repos])
    OpentelemetryOban.setup(trace: [:jobs])

    children = [
      JobService.Repo,
      {Bandit, plug: JobRouter, port: 8082},
      {Oban, Application.fetch_env!(:job_svc, Oban)}
    ]

    opts = [strategy: :one_for_one, name: JobSvc.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
