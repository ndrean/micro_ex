defmodule JobService.Clients.ImageSvcClient do
  @moduledoc """
  HTTP client for communicating with image_svc.

  Centralizes all HTTP calls to image_svc endpoints.
  """

  require Logger

  defp image_svc_base_url, do: Application.get_env(:job_svc, :image_svc_base_url)
  defp image_svc_endpoints, do: Application.get_env(:job_svc, :image_svc_endpoints)
  defp user_svc_base_url, do: Application.get_env(:job_svc, :user_svc_base_url)
  defp user_svc_endpoints, do: Application.get_env(:job_svc, :user_svc_endpoints)

  @doc """
  Requests image conversion from image_svc.

  ## Parameters
  - `args`: Map with conversion parameters

  ## Returns
  - `:ok` on success
  - `{:error, reason}` on failure
  """

  @spec convert_image(map()) :: :ok | {:error, any()}
  def convert_image(args) do
    request = %Mcsv.V2.ImageConversionRequest{
      user_id: args["user_id"],
      user_email: args["user_email"],
      image_url: args["image_url"],
      image_data: <<>>,
      input_format: args["input_format"] || "png",
      pdf_quality: args["pdf_quality"] || "high",
      strip_metadata: args["strip_metadata"] != false,
      max_width: args["max_width"] || 0,
      max_height: args["max_height"] || 0,
      storage_id: args["storage_id"]
    }

    request_binary = Mcsv.V2.ImageConversionRequest.encode(request)

    case post(image_svc_base_url(), image_svc_endpoints().convert_image, request_binary) do
      {:ok, %{status: 200, body: response_binary}} ->
        response = Mcsv.V2.ImageConversionResponse.decode(response_binary)

        if response.success do
          Logger.info("[Job][ImageSvcClient] Conversion acknowledged: #{response.message}")
          # Forward the entire response_binary to user_svc without re-encoding
          Logger.info("[Job][ImageSvcClient] Forwarding result to user_svc")
          post(user_svc_base_url(), user_svc_endpoints().notify_image_converted, response_binary)
          :ok
        else
          Logger.error("[Job][ImageSvcClient] Conversion failed: #{response.message}")
          {:error, response.message}
        end

      {:ok, %{status: status, body: body}} ->
        reason = Mcsv.V2.ImageConversionResponse.decode(body)
        Logger.error("[Job][ImageSvcClient] HTTP #{reason}")
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        Logger.error("[Job][ImageSvcClient] Request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private HTTP helper

  @spec post(binary(), binary(), binary(), list()) :: {:ok, any()} | {:error, any()}
  defp post(base, path, body, opts \\ []) do
    receive_timeout = Keyword.get(opts, :receive_timeout, 60_000)

    case Req.post(
           Req.new(base_url: base)
           |> OpentelemetryReq.attach(propagate_trace_headers: true),
           url: path,
           body: body,
           headers: [{"content-type", "application/protobuf"}],
           receive_timeout: receive_timeout
         ) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end
end
