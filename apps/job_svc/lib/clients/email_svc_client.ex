defmodule JobService.Clients.EmailSvcClient do
  @moduledoc """
  HTTP client for communicating with email_svc.

  Centralizes all HTTP calls to email_svc endpoints.
  """

  require Logger

  defp base_email_url, do: Application.get_env(:job_svc, :email_svc_base_url)
  defp base_job_url, do: Application.get_env(:job_svc, :job_svc_base_url)
  defp email_svc_endpoint, do: Application.get_env(:job_svc, :email_svc_endpoints)
  defp job_svc_endpoints, do: Application.get_env(:job_svc, :job_svc_endpoints)

  @doc """
  Sends an email request to email_svc.

  ## Parameters
  - `args`: Map with user info (id, name, email, type)

  ## Returns
  - `:ok` on success
  - `{:error, reason}` on failure
  """
  def send_email(args) do
    request = %Mcsv.EmailRequest{
      user_id: args["id"],
      user_name: args["name"],
      user_email: args["email"],
      email_type: args["type"]
    }

    request_binary = Mcsv.EmailRequest.encode(request)

    # Logger.info("[EmailSvcClient] Sending #{args["type"]} email to #{args["email"]}")

    case post(base_email_url(), email_svc_endpoint().send_email, request_binary) do
      {:ok, %{status: 200, body: response_binary}} ->
        # Notify job_svc about email delivery
        notify_email_delivery(response_binary)
        :ok

      {:ok, %{status: status}} ->
        Logger.error("[EmailSvcClient] HTTP #{status}")
        notify_email_delivery_failure()
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        Logger.error("[EmailSvcClient] Request failed: #{inspect(reason)}")
        notify_email_delivery_failure()
        {:error, reason}
    end
  end

  # Private helpers

  defp notify_email_delivery(response_body) do
    # Post back to job_svc's callback endpoint
    post(base_job_url(), job_svc_endpoints().notify_email_delivery, response_body)
  end

  defp notify_email_delivery_failure do
    failure_response =
      %Mcsv.EmailResponse{
        message: "Failed to send",
        success: false
      }
      |> Mcsv.EmailResponse.encode()

    post(base_job_url(), job_svc_endpoints().notify_email_delivery, failure_response)
  end

  defp post(base, path, body, opts \\ []) do
    receive_timeout = Keyword.get(opts, :receive_timeout, 30_000)

    case Req.post(
           Req.new(base_url: base),
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
