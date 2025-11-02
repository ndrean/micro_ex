defmodule Clients.UserSvcClient do
  @moduledoc """
  HTTP client for user_svc communication from job_svc.

  Handles notifications about email delivery status.
  """

  require Logger

  @base_url Application.compile_env(:job_svc, :user_svc_base_url)
  @endpoints Application.compile_env(:job_svc, :user_svc_endpoints)

  @doc """
  Notifies user_svc that an email has been sent.

  ## Parameters
  - `email_response_binary`: Encoded EmailResponse protobuf

  ## Returns
  - `{:ok, response}` on success
  - `{:error, reason}` on failure
  """
  def notify_email_sent(email_response_binary) do
    Logger.info("[UserSvcClient] Notifying user_svc of email delivery")

    post(@base_url, @endpoints.notify_email_sent, email_response_binary)
  end

  # Private HTTP helper

  defp post(base, path, body) do
    case Req.post(
           Req.new(base_url: base),
           url: path,
           body: body,
           headers: [{"content-type", "application/protobuf"}],
           receive_timeout: 10_000
         ) do
      {:ok, %{status: 204}} ->
        Logger.info("[UserSvcClient] Notification sent successfully")
        {:ok, :notified}

      {:ok, %{status: status, body: body}} ->
        Logger.error("[UserSvcClient] Unexpected status #{status}: #{inspect(body)}")
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        Logger.error("[UserSvcClient] Request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
