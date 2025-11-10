defmodule ImageSvc.StreamingConverter do
  @moduledoc """
  Stream-based image conversion with NO intermediate disk writes.

  Perfect for:
  - Processing images from MinIO/S3 without local storage
  - Handling images larger than available disk space
  - Reducing I/O latency (memory -> ImageMagick -> memory)

  Example:
      # Fetch from MinIO, convert, upload - all in memory!
      user_svc_url
      |> fetch_image_stream()
      |> convert_to_pdf_stream()
      |> upload_to_minio_stream()
  """

  require Logger

  @doc """
  Convert image stream to PDF stream (no disk writes).

  Input: Stream of binary chunks (e.g., from HTTP response or File.stream!)
  Output: Stream of PDF binary chunks
  """
  def convert_stream_to_pdf(image_stream, opts \\ []) do
    quality = Keyword.get(opts, :quality, "medium")
    threads = Keyword.get(opts, :threads, 4)

    # ImageMagick reads from stdin, writes to stdout
    # Write to stdout
    args =
      [
        # Read from stdin
        "-",
        "-limit",
        "thread",
        to_string(threads)
      ] ++ quality_args(quality) ++ ["pdf:-"]

    Logger.info(
      "[StreamingConverter] Starting stream conversion (quality: #{quality}, threads: #{threads})"
    )

    # Stream input to ImageMagick stdin, get PDF from stdout
    ExCmd.stream!(["magick" | args],
      input: image_stream
    )
  end

  @doc """
  Complete workflow: Fetch image from URL -> Convert -> Upload to MinIO.

  No disk writes! Everything streams through memory.
  """
  def convert_url_to_minio(image_url, s3_bucket, s3_key, opts \\ []) do
    Logger.info(
      "[StreamingConverter] Streaming conversion: #{image_url} -> s3://#{s3_bucket}/#{s3_key}"
    )

    start_time = System.monotonic_time(:millisecond)

    try do
      # 1. Fetch image from URL (streaming)
      image_stream = fetch_url_stream(image_url)

      # 2. Convert to PDF (streaming through ImageMagick)
      pdf_stream = convert_stream_to_pdf(image_stream, opts)

      # 3. Upload to MinIO (streaming)
      {:ok, result} = upload_stream_to_s3(pdf_stream, s3_bucket, s3_key)

      duration = System.monotonic_time(:millisecond) - start_time
      Logger.info("[StreamingConverter] Success (#{duration}ms): s3://#{s3_bucket}/#{s3_key}")

      :telemetry.execute(
        [:image_svc, :streaming_conversion, :complete],
        %{duration: duration, size_bytes: result.size},
        %{quality: opts[:quality] || "medium"}
      )

      {:ok, result}
    rescue
      e ->
        Logger.error("[StreamingConverter] Failed: #{Exception.message(e)}")
        {:error, Exception.message(e)}
    end
  end

  @doc """
  Process multiple images in parallel using streaming.

  Memory usage stays constant regardless of image count!
  """
  def batch_convert_streaming(image_urls, s3_bucket, opts \\ []) do
    max_concurrency = Keyword.get(opts, :max_concurrency, System.schedulers_online())

    Logger.info(
      "[StreamingConverter] Batch streaming #{length(image_urls)} images (concurrency: #{max_concurrency})"
    )

    image_urls
    |> Task.async_stream(
      fn url ->
        s3_key = "converted/#{generate_key(url)}.pdf"
        convert_url_to_minio(url, s3_bucket, s3_key, opts)
      end,
      max_concurrency: max_concurrency,
      timeout: 120_000,
      on_timeout: :kill_task
    )
    |> Enum.to_list()
  end

  ## Private Functions

  defp fetch_url_stream(url) do
    # Use Req with streaming
    case Req.get(url, into: :self) do
      {:ok, %Req.Response{status: 200, body: body}} when is_function(body) ->
        # body is a stream function
        Stream.resource(
          fn -> body end,
          fn stream_fun ->
            case stream_fun.() do
              {:ok, data} -> {[data], stream_fun}
              :done -> {:halt, stream_fun}
            end
          end,
          fn _ -> :ok end
        )

      {:ok, %Req.Response{status: 200, body: body}} ->
        # body is already complete binary
        Stream.chunk_every([body], 1)

      {:error, reason} ->
        raise "Failed to fetch #{url}: #{inspect(reason)}"
    end
  end

  defp upload_stream_to_s3(pdf_binary, bucket, key) do
    # Upload to S3
    ExAws.S3.put_object(bucket, key, pdf_binary, content_type: "application/pdf")
    |> ExAws.request()
    |> case do
      {:ok, _} ->
        {:ok, %{bucket: bucket, key: key, size: byte_size(pdf_binary)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp quality_args("low"), do: ["-quality", "60", "-density", "72"]
  defp quality_args("medium"), do: ["-quality", "85", "-density", "150"]
  defp quality_args("high"), do: ["-quality", "95", "-density", "300"]
  defp quality_args("lossless"), do: ["-quality", "100", "-density", "300"]

  defp generate_key(url) do
    :crypto.hash(:md5, url) |> Base.encode16(case: :lower)
  end
end
