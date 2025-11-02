defmodule JobSvc.Metrics do
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
    Logger.info("[Job-Metrics] Starting Prometheus metrics exporter")

    children = [
      # Define metrics and start the Prometheus Core (metrics only, no HTTP)
      {TelemetryMetricsPrometheus.Core, metrics: metrics(), name: :job_svc_metrics}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  # Define what metrics to collect
  defp metrics do
    [
      # HTTP request metrics (from Plug.Telemetry)
      Telemetry.Metrics.counter("job_svc.plug.stop.duration",
        event_name: [:job_svc, :plug, :stop],
        measurement: :duration,
        unit: {:native, :millisecond},
        tags: [:route],
        tag_values: fn metadata -> %{route: metadata[:route] || "unknown"} end,
        description: "Total number of HTTP requests"
      ),
      Telemetry.Metrics.distribution("job_svc.plug.stop.duration",
        event_name: [:job_svc, :plug, :stop],
        measurement: :duration,
        unit: {:native, :millisecond},
        tags: [:route],
        tag_values: fn metadata ->
          %{route: metadata[:route] || metadata[:request_path] || "unknown"}
        end,
        description: "HTTP request duration",
        reporter_options: [buckets: [10, 50, 100, 250, 500, 1000, 2500, 5000, 10_000]]
      ),

      # Image conversion metrics
      # Telemetry.Metrics.counter("image_svc.conversion.count",
      #   tags: [:status],
      #   description: "Total number of image conversions"
      # ),
      # Telemetry.Metrics.distribution("image_svc.conversion.duration",
      #   unit: {:native, :millisecond},
      #   description: "Job conversion duration",
      #   reporter_options: [buckets: [100, 500, 1000, 2000, 5000, 10_000, 30_000]]
      # ),
      # Telemetry.Metrics.distribution("image_svc.conversion.input_size",
      #   unit: :byte,
      #   description: "Input image size in bytes",
      #   reporter_options: [
      #     buckets: [1024, 10_240, 102_400, 512_000, 1_048_576, 5_242_880, 10_485_760]
      #   ]
      # ),
      # Telemetry.Metrics.distribution("image_svc.conversion.output_size",
      #   unit: :byte,
      #   description: "Output PDF size in bytes",
      #   reporter_options: [
      #     buckets: [1024, 10_240, 102_400, 512_000, 1_048_576, 5_242_880, 10_485_760]
      #   ]
      # ),

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

  @doc """
  Emit telemetry event for image conversion.

  Example:
      Metrics.emit_conversion(:success, duration_ms, input_size, output_size)
  """
  def emit_conversion(status, duration_ms, input_size, output_size) do
    :telemetry.execute(
      [:job_svc, :conversion],
      %{
        duration: duration_ms,
        input_size: input_size,
        output_size: output_size,
        count: 1
      },
      %{status: status}
    )
  end
end
