defmodule ImageMagick do
  @moduledoc """
  ImageMagick utilities for image identification and format detection.

  Note: ImageMagick uses Ghostscript internally for PDF rendering.
  Both tools must be installed for image-to-PDF conversion to work.
  """

  require Logger
  require OpenTelemetry.Tracer

  @doc """
  Check if required image processing tools are installed.

  We need both:
  - ImageMagick (`magick`) for image format detection and conversion
  - Ghostscript (`gs`) for PDF rendering (used internally by ImageMagick)

  ## Examples

      iex> ImageMagick.check()
      :ok
  """
  def check do
    with {:ok, magick_version} <- check_imagemagick(),
         {:ok, gs_version} <- check_ghostscript() do
      Logger.info("[ImageMagick] ImageMagick: #{magick_version}")
      Logger.info("[ImageMagick] Ghostscript: #{gs_version}")
      :ok
    else
      {:error, reason} ->
        Logger.error("[ImageMagick] Startup check failed: #{reason}")
        raise reason
    end
  end

  defp check_imagemagick do
    case System.cmd("magick", ["-version"]) do
      {output, 0} ->
        version =
          output
          |> String.split("\n")
          |> List.first()
          |> String.trim()

        {:ok, version}

      {_error, _} ->
        {:error, "ImageMagick not found - required for image format detection"}
    end
  end

  defp check_ghostscript do
    case System.cmd("gs", ["--version"]) do
      {output, 0} ->
        version = String.trim(output)
        {:ok, "Ghostscript #{version}"}

      {_error, _} ->
        {:error, "Ghostscript not found - required for PDF conversion"}
    end
  end

  def get_image_info(image_binary) when is_binary(image_binary) do
    OpenTelemetry.Tracer.with_span "imagemagick.identify", %{
      "image.size_bytes" => byte_size(image_binary)
    } do
      # Use temp file since System.cmd doesn't support stdin easily
      tmp_dir = System.tmp_dir!()

      tmp_file =
        Path.join(tmp_dir, "imageconverter_identify_#{System.unique_integer([:positive])}.img")

      try do
        File.write!(tmp_file, image_binary)

        # Use identify to get image info
        # Format: width height format
        # ImageMagick v7: use "magick identify"
        args = ["identify", "-format", "%w %h %m", tmp_file]

        case System.cmd("magick", args, stderr_to_stdout: true) do
          {output, 0} ->
            case String.split(String.trim(output)) do
              [width_str, height_str, format] ->
                result = %{
                  width: String.to_integer(width_str),
                  height: String.to_integer(height_str),
                  format: format,
                  size: byte_size(image_binary)
                }

                OpenTelemetry.Tracer.set_attributes(%{
                  "image.width" => result.width,
                  "image.height" => result.height,
                  "image.format" => result.format
                })

                {:ok, result}

              _ ->
                OpenTelemetry.Tracer.set_status(:error, "Could not parse image info")
                {:error, "[Image] Could not parse image info"}
            end

          {error, _exit_code} ->
            OpenTelemetry.Tracer.set_status(:error, "Failed to get image info: #{error}")
            {:error, "[Image] Failed to get image info: #{error}"}
        end
      catch
        _ ->
          OpenTelemetry.Tracer.set_status(:error, "Failed to get image info")
          {:error, "[Image] Failed to get image info"}
      after
        File.rm(tmp_file)
      end
    end
  end
end
