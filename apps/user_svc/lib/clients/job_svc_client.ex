defmodule Clients.JobSvcClient do
  @moduledoc """
  HTTP client for communicating with job_svc.

  Handles requests to enqueue jobs for async processing.
  """

  require Logger

  defp job_base_url, do: Application.get_env(:user_svc, :job_svc_base_url)
  defp job_endpoints, do: Application.get_env(:user_svc, :job_svc_endpoints)

  @doc """
  Requests image conversion from job_svc.

  ## Parameters
  - `request`: ImageConversionRequest struct with image_url

  ## Returns
  - `{:ok, message}` on success
  - `{:error, reason}` on failure
  """
  def convert_image(%Mcsv.ImageConversionRequest{} = request) do
    request_binary = Mcsv.ImageConversionRequest.encode(request)

    Logger.info(
      "[JobSvcClient] Requesting image conversion (#{byte_size(request_binary)} bytes with image_url)"
    )

    case post(job_base_url(), job_endpoints().convert_image, request_binary) do
      {:ok, %{status: 200, body: response_binary}} ->
        {:ok, response_binary}

      {:ok, %{status: status}} ->
        Logger.error("[JobSvcClient] HTTP #{status}")
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        Logger.error("[JobSvcClient] Request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Enqueues an email job.

  ## Parameters
  - `user_request_binary`: Encoded UserRequest protobuf

  ## Returns
  - `{:ok, job_id}` on success
  - `{:error, reason}` on failure
  """
  def enqueue_email(user_request_binary) do
    case post(job_base_url(), job_endpoints().enqueue_email, user_request_binary) do
      {:ok, %{status: 200, body: response_binary}} ->
        # {:ok, Mcsv.UserResponse.decode(response_binary) |> dbg()}
        {:ok, response_binary}

      {:ok, %{status: status, body: body}} ->
        Logger.error("[JobSvcClient] HTTP #{status}: #{inspect(body)}")
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        Logger.error("[JobSvcClient] Request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private HTTP helper

  defp post(base, path, body, opts \\ []) do
    receive_timeout = Keyword.get(opts, :receive_timeout, 30_000)

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
