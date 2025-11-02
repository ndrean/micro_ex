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
          image_svc: :permanent,
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

      # OpenTelemetry for distributed tracing
      {:opentelemetry_api, "~> 1.5"},
      {:opentelemetry, "~> 1.7"},
      {:opentelemetry_exporter, "~> 1.10"},
      {:tls_certificate_check, "~> 1.29"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
