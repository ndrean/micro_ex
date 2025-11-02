defmodule UserSvc.MixProject do
  use Mix.Project

  def project do
    [
      app: :user_svc,
      version: "0.1.0",
      # build_path: "/_build",
      config_path: "config/config.exs",
      deps_path: "deps",
      lockfile: "mix.lock",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        user_svc: [
          user_svc: :permanent,
          opentelemetry_exporter: :permanent,
          opentelemetry: :temporary
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      # Only include OTP apps that need explicit startup ordering
      extra_applications: [:logger, :tls_certificate_check],
      mod: {UserApp, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bandit, "~> 1.8"},
      {:plug, "~> 1.18"},
      {:jason, "~> 1.4"},
      {:req, "~> 0.5.15"},
      {:req_s3, "~> 0.2.3"},
      {:protobuf, "~> 0.15.0"},

      # OpenTelemetry for distributed tracing
      {:opentelemetry, "~> 1.7"},
      {:opentelemetry_api, "~> 1.5"},
      {:opentelemetry_exporter, "~> 1.10"},
      {:tls_certificate_check, "~> 1.29"},

      # S3/MinIO client
      {:ex_aws, "~> 2.5"},
      {:ex_aws_s3, "~> 2.5"},
      {:hackney, "~> 1.20"},
      {:sweet_xml, "~> 0.7"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}

      # {:sibling_app_in_umbrella, in_umbrella: true}
    ]
  end
end
