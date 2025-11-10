defmodule JobService.Clients.EmailSvcClient do
  @moduledoc """
  HTTP client for communicating with email_svc.

  Centralizes all HTTP calls to email_svc endpoints.
  """

  require Logger

  defp base_email_url, do: Application.get_env(:job_svc, :email_svc_base_url)
  defp base_user_url, do: Application.get_env(:job_svc, :user_svc_base_url)
  defp email_svc_endpoint, do: Application.get_env(:job_svc, :email_svc_endpoints)
  defp user_svc_endpoints, do: Application.get_env(:job_svc, :user_svc_endpoints)

  @doc """
  Sends an email request to email_svc.

  ## Parameters
  - `args`: Map with user info (id, name, email, type)

  ## Returns
  - `:ok` on success
  - `{:error, reason}` on failure
  """
  @spec send_email(map()) :: :ok | {:error, any()}
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
        # Notify user_svc about email delivery directly
        notify_user_svc(response_binary)
        :ok

      {:ok, %{status: status}} ->
        Logger.error("[Job][EmailSvcClient] HTTP #{status}")
        notify_user_svc_failure()
        {:error, "[Job] HTTP #{status}"}

      {:error, reason} ->
        Logger.error("[Job][EmailSvcClient] Request failed: #{inspect(reason)}")
        notify_user_svc_failure()
        {:error, reason}
    end
  end

  # Private helpers

  @spec notify_user_svc(binary()) :: :ok | {:error, any()}
  defp notify_user_svc(response_body) do
    # Post directly to user_svc (no intermediate hop through job_svc)
    Logger.info("[Job][EmailSvcClient] Notifying user_svc of email delivery")
    post(base_user_url(), user_svc_endpoints().notify_email_sent, response_body)
  end

  defp notify_user_svc_failure do
    failure_response =
      %Mcsv.EmailResponse{
        user_id: "",
        email: "",
        message: "[Job] Failed to send email",
        success: false
      }
      |> Mcsv.EmailResponse.encode()

    post(base_user_url(), user_svc_endpoints().notify_email_sent, failure_response)
  end

  @spec post(binary(), binary(), binary(), list()) :: {:ok, any()} | {:error, any()}
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
