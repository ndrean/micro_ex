defmodule NotifyImageConvertedController do
  @moduledoc """
  Handles notifications from job_svc about completed image conversions.

  Receives ImageConversionResponse from job_svc and forwards to client_svc.
  """

  use UserSvcWeb, :controller
  require Logger

  alias Clients.ClientSvcClient

  @doc """
  Receives ImageConversionResponse binary from job_svc, decodes it,
  and forwards to client_svc for user notification.
  """
  def forward(conn, _) do
    with {:ok, binary_body, conn} <- Plug.Conn.read_body(conn),
         {:ok, response} <- decode_image_conversion_response(binary_body) do
      Logger.info(
        "[User][NotifyImageConverted] Received conversion result: success=#{response.success}, storage_id=#{response.storage_id}"
      )

      # Forward to client_svc (async)
      ClientSvcClient.notify_image_converted(response)

      conn
      |> send_resp(204, "")
    else
      {:error, reason} ->
        Logger.error("[User][NotifyImageConverted] Failed to process: #{inspect(reason)}")

        conn
        |> put_status(400)
        |> json(%{error: "Invalid request"})
    end
  end

  defp decode_image_conversion_response(binary_body) do
    try do
      response = Mcsv.V2.ImageConversionResponse.decode(binary_body)
      {:ok, response}
    rescue
      e ->
        Logger.error("[User][NotifyImageConverted] Decode error: #{Exception.message(e)}")
        {:error, :decode_error}
    end
  end
end
