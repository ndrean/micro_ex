defmodule JobService.Metrics do
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

    # Ensure :os_mon application is started for CPU measurements
    Application.ensure_all_started(:os_mon)

    children = [
      # Telemetry poller for custom measurements (CPU utilization, Oban queue length)
      {:telemetry_poller,
       measurements: [
         {__MODULE__, :measure_cpu_utilization, []},
         {__MODULE__, :measure_oban_queue_length, []}
       ],
       period: :timer.seconds(5),
       name: :job_svc_poller},
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
      ),

      # CPU utilization (custom measurement)
      Telemetry.Metrics.last_value("job_svc.cpu.utilization",
        unit: :percent,
        description: "Average CPU utilization percentage across all cores"
      ),

      # Oban queue length metrics (custom measurement)
      Telemetry.Metrics.last_value("job_svc.oban.queue_length",
        tags: [:queue],
        description: "Number of jobs waiting in each Oban queue"
      ),
      Telemetry.Metrics.last_value("job_svc.oban.executing_count",
        tags: [:queue],
        description: "Number of jobs currently executing in each Oban queue"
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

  @doc """
  Measure CPU utilization and emit telemetry event.

  Called periodically by telemetry_poller (every 5 seconds).
  Uses :cpu_sup from :os_mon to get CPU utilization across all cores.
  """
  def measure_cpu_utilization do
    try do
      # Get CPU utilization: returns list of {CPU, Busy, NonBusy, Misc}
      # or a single {all, Busy, NonBusy, Misc} tuple for overall utilization
      case :cpu_sup.util() do
        {:all, busy, _non_busy, _misc} ->
          # Busy is already a percentage (0-100)
          :telemetry.execute(
            [:job_svc, :cpu],
            %{utilization: busy},
            %{}
          )

        cpu_list when is_list(cpu_list) ->
          # Calculate average across all CPUs
          total_busy =
            Enum.reduce(cpu_list, 0, fn {_cpu, busy, _non_busy, _misc}, acc ->
              acc + busy
            end)

          avg_busy = total_busy / length(cpu_list)

          :telemetry.execute(
            [:job_svc, :cpu],
            %{utilization: avg_busy},
            %{}
          )

        _other ->
          # If cpu_sup is not available or returns unexpected format, do nothing
          :ok
      end
    rescue
      _ ->
        # If :cpu_sup is not available, silently skip
        :ok
    end
  end

  @doc """
  Measure Oban queue lengths and emit telemetry events.

  Called periodically by telemetry_poller (every 5 seconds).
  Queries Oban for queue statistics and emits separate events for each queue.
  """
  def measure_oban_queue_length do
    try do
      # Get queue configuration from Oban
      oban_config = Application.fetch_env!(:job_svc, Oban)
      queues = Keyword.get(oban_config, :queues, [])

      # For each queue, get stats and emit telemetry
      Enum.each(queues, fn {queue_name, _limit} ->
        case Oban.check_queue(Oban, queue: queue_name) do
          %{available: available, running: running} ->
            # Emit queue_length metric (jobs waiting)
            :telemetry.execute(
              [:job_svc, :oban],
              %{queue_length: available},
              %{queue: queue_name}
            )

            # Emit executing_count metric (jobs currently running)
            :telemetry.execute(
              [:job_svc, :oban],
              %{executing_count: running},
              %{queue: queue_name}
            )

          _error ->
            # Queue not available yet, skip
            :ok
        end
      end)
    rescue
      _ ->
        # If Oban is not available or check_queue fails, silently skip
        :ok
    end
  end
end
