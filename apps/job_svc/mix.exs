defmodule JobSvc.MixProject do
  use Mix.Project

  def project do
    [
      app: :job_svc,
      version: "0.1.0",
      # build_path: "/_build",
      config_path: "config/config.exs",
      deps_path: "deps",
      lockfile: "mix.lock",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        job_svc: [
          job_svc: :permanent,
          opentelemetry_exporter: :permanent,
          opentelemetry: :temporary
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [
        :logger,
        :tls_certificate_check
      ],
      mod: {JobApp, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bandit, "~> 1.8"},
      {:req, "~> 0.5.15"},
      {:protobuf, "~> 0.15.0"},
      #  Background jobs
      {:oban, "~> 2.20"},
      # OpenTelemetry for distributed tracing
      {:opentelemetry_api, "~> 1.5"},
      {:opentelemetry_oban, "~> 1.1"},
      {:opentelemetry_ecto, "~> 1.2"},
      {:opentelemetry, "~> 1.7"},
      {:opentelemetry_exporter, "~> 1.10"},
      {:tls_certificate_check, "~> 1.29"},

      # Email
      {:ecto_sql, "~> 3.12"},
      {:ecto_sqlite3, "~> 0.18"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
