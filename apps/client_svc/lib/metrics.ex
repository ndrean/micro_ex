defmodule ClientSvc.Metrics do
  @moduledoc """
  Prometheus metrics for image_svc.

  Exposes metrics at /metrics endpoint for Prometheus scraping.
  """

  use Supervisor
  require Logger

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    Logger.info("[Client-Metrics] Starting Prometheus metrics exporter")

    children = [
      # Define metrics and start the Prometheus Core (metrics only, no HTTP)
      {TelemetryMetricsPrometheus.Core, metrics: metrics(), name: :client_svc_metrics}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  # Define what metrics to collect
  defp metrics do
    [
      # HTTP request metrics (from Plug.Telemetry)
      Telemetry.Metrics.counter("client_svc.plug.stop.duration",
        event_name: [:client_svc, :plug, :stop],
        measurement: :duration,
        unit: {:native, :millisecond},
        tags: [:route],
        tag_values: fn metadata -> %{route: metadata[:route] || "unknown"} end,
        description: "Total number of HTTP requests"
      ),
      Telemetry.Metrics.distribution("client_svc.plug.stop.duration",
        event_name: [:client_svc, :plug, :stop],
        measurement: :duration,
        unit: {:native, :millisecond},
        tags: [:route],
        tag_values: fn metadata ->
          %{route: metadata[:route] || metadata[:request_path] || "unknown"}
        end,
        description: "HTTP request duration",
        reporter_options: [buckets: [10, 50, 100, 250, 500, 1000, 2500, 5000, 10_000]]
      ),

      # VM metrics (automatically collected by telemetry_poller)
      Telemetry.Metrics.last_value("vm.memory.total",
        unit: :byte,
        description: "Total memory used by the BEAM VM"
      ),
      Telemetry.Metrics.last_value("vm.total_run_queue_lengths.total",
        description: "Total run queue length"
      ),
      Telemetry.Metrics.last_value("vm.total_run_queue_lengths.cpu",
        description: "CPU scheduler run queue length"
      ),

      # System metrics
      Telemetry.Metrics.last_value("vm.system_counts.process_count",
        description: "Number of processes"
      ),
      Telemetry.Metrics.last_value("vm.system_counts.port_count",
        description: "Number of ports"
      )
    ]
  end
end
