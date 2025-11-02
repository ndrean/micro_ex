defmodule ImageClient do
  @moduledoc """
  Client for testing PNG to PDF conversion via microservices.

  ## Examples

      # Convert a single PNG file
      ImageClient.convert_png("test.png", "user@example.com")

      # Convert with options
      ImageClient.convert_png("large.png", "user@example.com",
        quality: "high",
        max_width: 2000
      )

      # Convert multiple images concurrently
      ImageClient.convert_many_pngs(["img1.png", "img2.png", "img3.png"])
  """

  require OpenTelemetry.Tracer, as: Tracer

  @base_user_url Application.compile_env(:client_svc, :user_svc_base_url)
  @user_endpoints Application.compile_env(:client_svc, :user_endpoints)

  @doc """
  Convert a PNG file to PDF via the microservice pipeline.

  ## Options

    - `:quality` - "low", "medium", "high", "lossless" (default: "high")
    - `:strip_metadata` - Remove EXIF data (default: true)
    - `:max_width` - Maximum width in pixels
    - `:max_height` - Maximum height in pixels

  ## Examples

      iex> ImageClient.convert_png("test.png", "user@example.com")
      %Mcsv.UserResponse{ok: true, message: "Image conversion job enqueued..."}
  """
  def convert_png(png_path, user_email, opts \\ []) do
    Tracer.with_span "#{__MODULE__}.create/1" do
      Tracer.set_attribute(:value, user_email)
      :ok
    end

    # Read PNG file
    png_binary = File.read!(png_path)
    png_size = byte_size(png_binary)

    IO.puts("📁 Reading PNG: #{png_path} (#{format_bytes(png_size)})")

    # Build protobuf request
    request_binary =
      %Mcsv.ImageConversionRequest{
        user_id: "test-user-#{:rand.uniform(1000)}",
        user_email: user_email,
        image_data: png_binary,
        input_format: "png",
        pdf_quality: Keyword.get(opts, :quality, "high"),
        strip_metadata: Keyword.get(opts, :strip_metadata, true),
        max_width: Keyword.get(opts, :max_width, 0),
        max_height: Keyword.get(opts, :max_height, 0)
      }
      |> Mcsv.ImageConversionRequest.encode()

    protobuf_size = byte_size(request_binary)

    IO.puts("Protobuf request: #{format_bytes(protobuf_size)}")
    IO.puts("Sending to User service...")

    # Measure request time
    {time_us, response} =
      :timer.tc(fn ->
        response =
          Req.post(
            Req.new(base_url: @base_user_url),
            url: @user_endpoints.convert_image,
            body: request_binary,
            headers: [{"content-type", "application/protobuf"}],
            receive_timeout: 5_000
          )

        case response do
          {:ok, %{status: 200, body: body}} ->
            Mcsv.UserResponse.decode(body)

          msg ->
            raise "Error: #{inspect(msg)}"
        end
      end)

    time_ms = time_us / 1000

    IO.puts("Response in #{time_ms}ms: #{response.message}")

    response
  end

  @doc """
  Convert multiple PNG files concurrently.

  ## Examples

      iex> ImageClient.convert_many_pngs(["img1.png", "img2.png"], concurrency: 5)
      {2, 0}  # {success_count, failed_count}
  """
  def convert_many_pngs(png_paths, opts \\ []) do
    concurrency = Keyword.get(opts, :concurrency, 5)
    user_email = Keyword.get(opts, :email, "test@example.com")

    IO.puts("Converting #{length(png_paths)} images with concurrency #{concurrency}...")

    start_time = System.monotonic_time(:millisecond)

    result =
      png_paths
      |> Task.async_stream(
        fn path ->
          convert_png(path, user_email, opts)
        end,
        max_concurrency: concurrency,
        timeout: 60_000
      )
      |> Enum.reduce({0, 0}, fn
        {:ok, %Mcsv.UserResponse{ok: true}}, {success, failed} ->
          {success + 1, failed}

        _, {success, failed} ->
          {success, failed + 1}
      end)

    end_time = System.monotonic_time(:millisecond)
    total_time = end_time - start_time

    {success, failed} = result

    IO.puts("\nResults:")
    IO.puts("  Success: #{success}")
    IO.puts("  Failed: #{failed}")
    IO.puts("  Total time: #{total_time}ms")
    IO.puts("  Avg per image: #{div(total_time, length(png_paths))}ms")

    result
  end

  @doc """
  Create a test PNG file for testing.

  ## Examples

      iex> ImageClient.create_test_png("test.png", width: 1920, height: 1080)
      :ok
  """
  def create_test_png(output_path, opts \\ []) do
    width = Keyword.get(opts, :width, 800)
    height = Keyword.get(opts, :height, 600)
    color = Keyword.get(opts, :color, "blue")

    # Use ImageMagick to create a test PNG
    # ImageMagick v7: use "magick convert"
    case System.cmd("magick", [
           "convert",
           "-size",
           "#{width}x#{height}",
           "xc:#{color}",
           "-pointsize",
           "72",
           "-gravity",
           "center",
           "-annotate",
           "+0+0",
           "Test Image\n#{width}x#{height}",
           output_path
         ]) do
      {_, 0} ->
        size = File.stat!(output_path).size
        IO.puts("Created test PNG: #{output_path} (#{format_bytes(size)})")
        :ok

      {error, _} ->
        {:error, error}
    end
  end

  @doc """
  Test PNG to PDF conversion locally (without microservices).

  Useful for quick testing of ImageMagick.

  ## Examples

      iex> ImageClient.test_local_conversion("input.png", "output.pdf")
      :ok
  """
  def test_local_conversion(png_path, pdf_path) do
    IO.puts("Testing local conversion: #{png_path} → #{pdf_path}")

    # Read PNG
    png_binary = File.read!(png_path)
    IO.puts("PNG size: #{format_bytes(byte_size(png_binary))}")

    # Convert using ImageMagick directly
    {time_us, result} =
      :timer.tc(fn ->
        case System.cmd("magick", ["convert", "#{png_path}", "#{pdf_path}"]) do
          {_, 0} -> :ok
          {error, _} -> {:error, error}
        end
      end)

    case result do
      :ok ->
        pdf_size = File.stat!(pdf_path).size
        IO.puts("Converted in #{time_us / 1000}ms")
        IO.puts("PDF size: #{format_bytes(pdf_size)}")
        IO.puts("Saved to: #{pdf_path}")
        :ok

      {:error, error} ->
        IO.puts("Conversion failed: #{error}")
        {:error, error}
    end
  end

  # Helper to format bytes
  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 2)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1024 / 1024, 2)} MB"
end
