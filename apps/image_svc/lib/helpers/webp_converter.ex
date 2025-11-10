defmodule ImageSvc.WebPConverter do
  @moduledoc """
  Convert images to WebP format using FFmpeg.

  FFmpeg advantages over ImageMagick for WebP:
  - Lighter weight process
  - Native WebP support via libwebp
  - Faster startup time
  - Better streaming performance

  Each conversion spawns a fresh FFmpeg process for simplicity and reliability.
  Phoenix's concurrency naturally parallelizes multiple requests.
  """

  require Logger

  @doc """
  Convert image binary to WebP format.

  Options:
  - :quality - 0-100 (default: 85)
  - :lossless - true/false (default: false)
  - :timeout - Max conversion time in ms (default: 30_000)

  ## Examples

      iex> ImageSvc.WebPConverter.convert_to_webp(png_binary, quality: 90)
      {:ok, webp_binary}

      iex> ImageSvc.WebPConverter.convert_to_webp(jpeg_binary, lossless: true)
      {:ok, webp_binary}
  """
  def convert_to_webp(image_binary, opts \\ []) when is_binary(image_binary) do
    quality = Keyword.get(opts, :quality, 85)
    lossless = Keyword.get(opts, :lossless, false)
    timeout = Keyword.get(opts, :timeout, 30_000)

    Logger.info(
      "[WebPConverter] Converting #{byte_size(image_binary)} bytes (quality: #{quality}, lossless: #{lossless})"
    )

    start_time = System.monotonic_time(:millisecond)

    # Build FFmpeg command for stdin -> WebP stdout
    args = build_ffmpeg_args(quality, lossless)

    try do
      # Start FFmpeg process
      {:ok, process} = ExCmd.Process.start_link(["ffmpeg" | args])

      # Write input binary to stdin
      :ok = ExCmd.Process.write(process, image_binary)

      # Close stdin to signal we're done writing
      :ok = ExCmd.Process.close_stdin(process)

      # Read all output from stdout
      webp_binary = read_all_output(process, <<>>)

      # Wait for process to exit
      case ExCmd.Process.await_exit(process, timeout) do
        {:ok, 0} ->
          duration = System.monotonic_time(:millisecond) - start_time

          Logger.info(
            "[WebPConverter] Success (#{duration}ms): #{byte_size(webp_binary)} bytes (#{compression_ratio(image_binary, webp_binary)}% compression)"
          )

          # Emit telemetry for metrics
          :telemetry.execute(
            [:image_svc, :webp_conversion, :complete],
            %{duration: duration, input_size: byte_size(image_binary), output_size: byte_size(webp_binary)},
            %{quality: quality, lossless: lossless}
          )

          {:ok, webp_binary}

        {:ok, exit_code} ->
          Logger.error("[WebPConverter] FFmpeg failed with exit code: #{exit_code}")
          {:error, {:conversion_failed, exit_code, "FFmpeg exited with code #{exit_code}"}}

        {:error, reason} ->
          Logger.error("[WebPConverter] Process error: #{inspect(reason)}")
          {:error, {:process_error, reason}}
      end
    rescue
      e ->
        Logger.error("[WebPConverter] Unexpected error: #{Exception.message(e)}")
        {:error, {:unexpected_error, Exception.message(e)}}
    end
  end

  ## Private Functions

  # Read all output from ExCmd.Process stdout
  defp read_all_output(process, acc) do
    case ExCmd.Process.read(process) do
      {:ok, data} -> read_all_output(process, acc <> data)
      :eof -> acc
    end
  end

  # Build FFmpeg args for image -> WebP conversion via stdin/stdout
  defp build_ffmpeg_args(quality, lossless) do
    base_args = [
      "-hide_banner",
      "-loglevel", "error",
      # Input from stdin, auto-detect format
      "-f", "image2pipe",
      "-i", "-"
    ]

    codec_args =
      if lossless do
        ["-c:v", "libwebp", "-lossless", "1", "-compression_level", "6"]
      else
        ["-c:v", "libwebp", "-quality", to_string(quality)]
      end

    output_args = [
      # Output WebP to stdout
      "-f", "webp",
      "-"
    ]

    base_args ++ codec_args ++ output_args
  end

  # Calculate compression ratio as percentage
  defp compression_ratio(input, output) do
    ratio = (1 - byte_size(output) / byte_size(input)) * 100
    Float.round(ratio, 1)
  end
end
