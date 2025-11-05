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
          applications: [
            opentelemetry_exporter: :permanent,
            opentelemetry: :temporary,
            job_svc: :permanent
          ],
          include_executables_for: [:unix],
          strip_beams: false
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :os_mon, :inets, :tls_certificate_check],
      mod: {JobApp, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bandit, "~> 1.8"},
      {:req, "~> 0.5.15"},
      {:jason, "~> 1.4"},
      {:protobuf, "~> 0.15.0"},
      #  Background jobs
      {:oban, "~> 2.20"},
      # OpenTelemetry for distributed tracing
      {:opentelemetry_exporter, "~> 1.10"},
      {:opentelemetry_api, "~> 1.5"},
      # Disabled: conflicts with opentelemetry_req semconv version
      # {:opentelemetry_oban, "~> 1.1"},
      {:opentelemetry_ecto, "~> 1.2"},
      {:opentelemetry, "~> 1.7"},
      {:opentelemetry_req, "~> 1.0"},
      {:tls_certificate_check, "~> 1.29"},

      # Prometheus metrics
      {:prom_ex, "~> 1.11.0"},
      {:telemetry_metrics_prometheus_core, "~> 1.2"},
      {:telemetry_poller, "~> 1.3"},

      # Structured JSON logging
      {:logger_json, "~> 7.0"},

      # OpenAPI documentation
      {:open_api_spex, "~> 3.21"},

      # MinIO / S3 (for cleanup worker)
      {:ex_aws, "~> 2.5"},
      {:ex_aws_s3, "~> 2.5"},
      {:hackney, "~> 1.20"},
      {:sweet_xml, "~> 0.7"},

      # Database
      {:ecto_sql, "~> 3.12"},
      {:ecto_sqlite3, "~> 0.18"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
