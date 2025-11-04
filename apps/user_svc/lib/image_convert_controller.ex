defmodule ConvertImageController do
  @moduledoc """
  Initiates image conversion workflow.

  Flow:
  1. Receives image from client
  2. Stores image temporarily with storage_id
  3. Sends metadata + image_url to job_svc
  4. Returns acknowledgment to client
  """

  require Logger
  import Plug.Conn

  alias Clients.JobSvcClient

  # Runtime config - reads from runtime.exs via environment variables
  defp user_svc_base_url, do: Application.get_env(:user_svc, :user_svc_base_url)

  def convert(conn) do
    with {:ok, %Mcsv.ImageConversionRequest{} = request, new_conn} <-
           decode_client_request(conn),
         {:ok, storage_id} <-
           store_image(request),
         {:ok, bin_message} <-
           forward_to_job_svc(request, storage_id) do
      # respond back to Client
      new_conn
      |> put_resp_content_type("application/protobuf")
      |> send_resp(200, bin_message)
    else
      {:error, reason} ->
        Logger.error("[ConvertImageController] Failed: #{inspect(reason)}")

        response_binary =
          ProtobufHelpers.build_user_failure("Failed to process request: #{inspect(reason)}")

        # respond back to Client
        conn
        |> put_resp_content_type("application/protobuf")
        |> send_resp(500, response_binary)
    end
  end

  # Request processing

  defp decode_client_request(conn) do
    case read_body(conn) do
      {:ok, binary_body, new_conn} ->
        {:ok, Mcsv.ImageConversionRequest.decode(binary_body), new_conn}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp store_image(request) do
    format = if request.input_format == "", do: "png", else: request.input_format

    case ImageStorage.store(request.image_data, request.user_id, format) do
      {:ok, storage_id} ->
        Logger.info("[ConvertImageController] Stored image as #{storage_id}")
        {:ok, storage_id}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_presigned_url(storage_id) do
    "#{user_svc_base_url()}/user_svc/ImageLoader/#{storage_id}"
  end

  defp forward_to_job_svc(request, storage_id) do
    # Build image URL for other services to fetch
    image_url = build_presigned_url(storage_id)

    Logger.info("[ConvertImageController] Image URL: #{image_url}")

    # Create request with image_url (no binary data)
    job_request = %Mcsv.ImageConversionRequest{
      user_id: request.user_id,
      user_email: request.user_email,
      image_url: image_url,
      image_data: <<>>,
      input_format: request.input_format,
      pdf_quality: request.pdf_quality,
      strip_metadata: request.strip_metadata,
      max_width: request.max_width,
      max_height: request.max_height,
      storage_id: storage_id
    }

    case JobSvcClient.convert_image(job_request) do
      {:ok, bin_resp} ->
        {:ok, bin_resp}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
