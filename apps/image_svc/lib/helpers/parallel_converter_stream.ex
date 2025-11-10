defmodule ImageSvc.ParallelConverterStream do
  @moduledoc """
  Convert images to PDF using ExCmd.stream! for streaming efficiency.

  This is an intermediate implementation that:
  - Uses ExCmd.stream! (vs ExCmd.Process in ParallelConverter)
  - Returns PDF binary (same interface as ParallelConverter)
  - Does NOT upload to MinIO yet (that's a later step)

  Key differences from ParallelConverter:
  - Streams data through ImageMagick instead of manual write/read
  - More memory efficient for large images
  - Simpler error handling (stream exceptions)
  """

  require Logger

  @doc """
  Convert image binary to PDF using streaming ImageMagick.

  Options:
  - :quality - "low" | "medium" | "high" | "lossless" (default: "medium")
  - :threads - Number of ImageMagick threads (default: auto-detect)

  Returns {:ok, pdf_binary} or {:error, reason}
  """
  def convert_to_pdf(image_binary, opts \\ []) when is_binary(image_binary) do
    quality = Keyword.get(opts, :quality, "medium")
    input_format = Keyword.get(opts, :input_format, "png")
    threads = Keyword.get(opts, :threads, System.schedulers_online())

    Logger.info(
      "[ParallelConverterStream] Converting #{byte_size(image_binary)} bytes (format: #{input_format}, quality: #{quality}, threads: #{threads})"
    )

    start_time = System.monotonic_time(:millisecond)

    # Build ImageMagick args for stdin -> stdout conversion
    args = build_streaming_args(input_format, quality, threads)

    # Create stream of binary chunks using Stream.unfold (proven to work in console)
    chunk_size = 65_536

    input_stream =
      Stream.unfold(image_binary, fn
        <<>> ->
          nil

        rest when byte_size(rest) > chunk_size ->
          {binary_part(rest, 0, chunk_size),
           binary_part(rest, chunk_size, byte_size(rest) - chunk_size)}

        rest ->
          {rest, <<>>}
      end)

    # Log the full command for debugging
    full_cmd = ["magick" | args]
    Logger.info("[ParallelConverterStream] Running: #{Enum.join(full_cmd, " ")}")

    try do
      # Stream without stderr capture first - simpler
      pdf_binary =
        ExCmd.stream!(full_cmd, input: input_stream)
        |> Enum.reduce(<<>>, fn chunk, acc -> acc <> chunk end)

      duration = System.monotonic_time(:millisecond) - start_time

      Logger.info(
        "[ParallelConverterStream] Success (#{duration}ms): #{byte_size(pdf_binary)} bytes"
      )

      # Emit telemetry for metrics
      :telemetry.execute(
        [:image_svc, :conversion, :complete],
        %{duration: duration, size_bytes: byte_size(pdf_binary)},
        %{quality: quality, threads: threads, method: :stream}
      )

      {:ok, pdf_binary}
    rescue
      e in ExCmd.Stream.AbnormalExit ->
        Logger.error(
          "[ParallelConverterStream] ImageMagick failed with exit code #{e.exit_status}: #{Exception.message(e)}"
        )

        Logger.error("[ParallelConverterStream] Command was: #{Enum.join(full_cmd, " ")}")

        {:error, {:conversion_failed, e.exit_status, Exception.message(e)}}

      e ->
        Logger.error("[ParallelConverterStream] Unexpected error: #{Exception.message(e)}")
        Logger.error("[ParallelConverterStream] Error: #{inspect(e)}")
        {:error, {:unexpected_error, Exception.message(e)}}
    end
  end

  ## Private Functions

  # Build args for streaming: stdin (format:-) -> stdout (pdf:-)
  defp build_streaming_args(input_format, quality, threads) do
    System.put_env("MAGICK_THREAD_LIMIT", to_string(threads))

    base_args = [
      # Specify input format explicitly when reading from stdin
      # e.g., "png:-" tells ImageMagick to read PNG from stdin
      "#{input_format}:-",
      "-limit",
      "thread",
      to_string(threads)
    ]

    quality_args = quality_settings(quality)

    base_args ++ quality_args ++ ["pdf:-"]
  end

  defp quality_settings("low") do
    [
      "-quality",
      "60",
      "-density",
      "72"
    ]
  end

  defp quality_settings("medium") do
    [
      "-quality",
      "85",
      "-density",
      "150"
    ]
  end

  defp quality_settings("high") do
    [
      "-quality",
      "95",
      "-density",
      "300"
    ]
  end

  defp quality_settings("lossless") do
    [
      "-quality",
      "100",
      "-density",
      "300"
    ]
  end
end
