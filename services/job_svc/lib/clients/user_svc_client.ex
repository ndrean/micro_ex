defmodule Clients.UserSvcClient do
  @moduledoc """
  HTTP client for user_svc communication from job_svc.

  Handles notifications about email delivery status.
  """

  require Logger

  defp user_base_url, do: Application.get_env(:job_svc, :user_svc_base_url)
  defp endpoints, do: Application.get_env(:job_svc, :user_svc_endpoints)

  @doc """
  Notifies user_svc that an email has been sent.

  ## Parameters
  - `email_response_binary`: Encoded EmailResponse protobuf

  ## Returns
  - `{:ok, :notified}` on success
  - `{:error, reason}` on failure
  """
  @spec notify_email_sent(binary()) :: {:ok, :notified} | {:error, any()}
  def notify_email_sent(email_response_binary) do
    Logger.info("[Job][UserSvcClient] Notifying user_svc of email delivery")

    post(user_base_url(), endpoints().notify_email_sent, email_response_binary)
  end

  # Private HTTP helper

  @spec post(binary(), binary(), binary()) :: {:ok, any()} | {:error, any()}
  defp post(base, path, body) do
    case Req.post(
           Req.new(base_url: base)
           |> OpentelemetryReq.attach(propagate_trace_headers: true),
           url: path,
           body: body,
           headers: [{"content-type", "application/protobuf"}],
           receive_timeout: 10_000
         ) do
      {:ok, %Req.Response{status: 204}} ->
        Logger.info("[Job][UserSvcClient] Notification sent successfully")
        {:ok, :notified}

      {:ok, %Req.Response{status: status, body: body} = _resp} ->
        Logger.error("[Job][UserSvcClient] Status #{status}: #{body}")
        {:error, "[Job] HTTP error: #{status}"}

      {:error, reason} ->
        Logger.error("[Job][UserSvcClient] Request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
