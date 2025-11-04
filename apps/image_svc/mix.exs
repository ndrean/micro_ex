defmodule ImageSvc.MixProject do
  use Mix.Project

  def project do
    [
      app: :image_svc,
      version: "0.1.0",
      config_path: "config/config.exs",
      deps_path: "deps",
      lockfile: "mix.lock",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        image_svc: [
          applications: [
            opentelemetry_exporter: :permanent,
            opentelemetry: :temporary
          ]
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
      mod: {ImageSvc.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bandit, "~> 1.8"},
      {:plug, "~> 1.16"},
      {:req, "~> 0.5.15"},
      {:protobuf, "~> 0.15.0"},
      {:jason, "~> 1.4"},

      # OpenTelemetry for distributed tracing (exporter MUST be before opentelemetry)
      {:opentelemetry_api, "~> 1.5"},
      {:opentelemetry_exporter, "~> 1.10"},
      {:opentelemetry, "~> 1.7"},
      {:opentelemetry_req, "~> 1.0"},
      {:tls_certificate_check, "~> 1.29"},

      # Prometheus metrics
      {:telemetry_metrics_prometheus_core, "~> 1.2"},
      {:telemetry_poller, "~> 1.3"},

      # Structured JSON logging
      {:logger_json, "~> 7.0"},

      # OpenAPI documentation
      {:open_api_spex, "~> 3.21"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
