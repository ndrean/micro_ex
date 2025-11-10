defmodule ImageConverter do
  #   @moduledoc """
  #   Convert images to PDF using ImageMagick.

  #   Handles binary data directly - perfect for protobuf workflows.

  #   ## Requirements

  #   ImageMagick must be installed:
  #   - macOS: `brew install imagemagick`
  #   - Ubuntu: `sudo apt-get install imagemagick`

  #   ## Examples

  #       # Convert PNG binary to PDF binary
  #       {:ok, pdf_binary} = ImageConverter.png_to_pdf(png_binary)

  #       # With options
  #       {:ok, pdf_binary} = ImageConverter.convert(png_binary,
  #         quality: "high",
  #         strip_metadata: true,
  #         max_width: 2000
  #       )
  #   """

  #   require Logger

  #   @doc """
  #   Convert PNG binary to PDF binary using ImageMagick.

  #   ## Examples

  #       iex> png_binary = File.read!("image.png")
  #       iex> {:ok, pdf_binary} = ImageConverter.png_to_pdf(png_binary)
  #       iex> File.write!("output.pdf", pdf_binary)
  #   """
  #   def png_to_pdf(png_binary) when is_binary(png_binary) do
  #     # Task.async(fn -> convert(png_binary, input_format: "png", output_format: "pdf") end)
  #     # |> Task.await(:infinity)
  #     convert(png_binary, input_format: "png", output_format: "pdf")
  #   end

  #   @doc """
  #   Convert image binary to PDF with options.

  #   ## Options

  #     - `:input_format` - Input format (default: "png")
  #     - `:output_format` - Output format (default: "pdf")
  #     - `:quality` - PDF quality: "low", "medium", "high", "lossless" (default: "high")
  #     - `:strip_metadata` - Remove EXIF data (default: true)
  #     - `:max_width` - Maximum width, resize if larger (default: nil)
  #     - `:max_height` - Maximum height, resize if larger (default: nil)

  #   ## Examples

  #       {:ok, pdf_binary} = ImageConverter.convert(png_binary,
  #         quality: "high",
  #         strip_metadata: true,
  #         max_width: 2000
  #       )
  #   """
  #   def convert(image_binary, opts \\ []) when is_binary(image_binary) do
  #     input_format = Keyword.get(opts, :input_format, "png")
  #     output_format = Keyword.get(opts, :output_format, "pdf")
  #     quality = Keyword.get(opts, :quality, "high")
  #     strip_metadata = Keyword.get(opts, :strip_metadata, true)
  #     max_width = Keyword.get(opts, :max_width)
  #     max_height = Keyword.get(opts, :max_height)

  #     # Use temp files for input/output since System.cmd doesn't support stdin/stdout easily
  #     tmp_dir = System.tmp_dir!()

  #     tmp_input =
  #       Path.join(
  #         tmp_dir,
  #         "imageconverter_input_#{System.unique_integer([:positive])}.#{input_format}"
  #       )

  #     tmp_output =
  #       Path.join(
  #         tmp_dir,
  #         "imageconverter_output_#{System.unique_integer([:positive])}.#{output_format}"
  #       )

  #     try do
  #       # Write input image to temp file
  #       File.write!(tmp_input, image_binary)

  #       # Build ImageMagick arguments (using file paths instead of stdin/stdout)
  #       args =
  #         build_convert_args_files(
  #           tmp_input,
  #           tmp_output,
  #           quality,
  #           strip_metadata,
  #           max_width,
  #           max_height
  #         )

  #       Logger.debug("[Image] ImageMagick: magick convert #{inspect(args)}")

  #       # Run ImageMagick convert command
  #       # ImageMagick v7 uses "magick convert"
  #       case System.cmd("magick", ["convert" | args], stderr_to_stdout: true) do
  #         {_output, 0} ->
  #           # Read the converted file
  #           pdf_binary = File.read!(tmp_output)
  #           {:ok, pdf_binary}

  #         {error, exit_code} ->
  #           Logger.error("[Image] ImageMagick conversion failed (exit #{exit_code}): #{error}")
  #           {:error, "[Image] Conversion failed: #{error}"}
  #       end
  #     catch
  #       _ -> {:error, "[Image] Conversion failed"}
  #     after
  #       # Clean up temp files
  #       File.rm(tmp_input)
  #       File.rm(tmp_output)
  #     end
  #   end

  # def get_image_info(image_binary) when is_binary(image_binary) do
  #   # Use temp file since System.cmd doesn't support stdin easily
  #   tmp_dir = System.tmp_dir!()

  #   tmp_file =
  #     Path.join(tmp_dir, "imageconverter_identify_#{System.unique_integer([:positive])}.img")

  #   try do
  #     File.write!(tmp_file, image_binary)

  #     # Use identify to get image info
  #     # Format: width height format
  #     # ImageMagick v7: use "magick identify"
  #     args = ["identify", "-format", "%w %h %m", tmp_file]

  #     case System.cmd("magick", args, stderr_to_stdout: true) do
  #       {output, 0} ->
  #         case String.split(String.trim(output)) do
  #           [width_str, height_str, format] ->
  #             {:ok,
  #              %{
  #                width: String.to_integer(width_str),
  #                height: String.to_integer(height_str),
  #                format: format,
  #                size: byte_size(image_binary)
  #              }}

  #           _ ->
  #             {:error, "[Image] Could not parse image info"}
  #         end

  #       {error, _exit_code} ->
  #         {:error, "[Image] Failed to get image info: #{error}"}
  #     end
  #   catch
  #     _ -> {:error, "[Image] Failed to get image info"}
  #   after
  #     File.rm(tmp_file)
  #   end
  # end

  #   # Private helpers

  #   defp build_convert_args_files(
  #          input_path,
  #          output_path,
  #          quality,
  #          strip_metadata,
  #          max_width,
  #          max_height
  #        ) do
  #     args = [input_path]

  #     # Strip metadata
  #     args = if strip_metadata, do: args ++ ["-strip"], else: args

  #     # Resize if needed
  #     args =
  #       case {max_width, max_height} do
  #         {nil, nil} -> args
  #         {w, nil} -> args ++ ["-resize", "#{w}x"]
  #         {nil, h} -> args ++ ["-resize", "x#{h}"]
  #         # > means only shrink, don't enlarge
  #         {w, h} -> args ++ ["-resize", "#{w}x#{h}>"]
  #       end

  #     # Quality settings for PDF
  #     args = args ++ quality_args(quality)

  #     # Output file path
  #     args ++ [output_path]
  #   end

  #   defp quality_args("low"), do: ["-quality", "60", "-compress", "JPEG"]
  #   defp quality_args("medium"), do: ["-quality", "85", "-compress", "JPEG"]
  #   defp quality_args("high"), do: ["-quality", "92", "-compress", "JPEG"]
  #   defp quality_args("lossless"), do: ["-compress", "Lossless"]
  #   # Default to high
  #   defp quality_args(_), do: quality_args("high")
end
