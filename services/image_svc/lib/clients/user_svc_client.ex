defmodule ImageSvc.UserSvcClient do
  @moduledoc """
  HTTP client for communicating with user_svc.

  Centralizes all HTTP calls to user_svc endpoints with consistent
  configuration and error handling.
  """

  require Logger

  defp user_base_url, do: Application.get_env(:image_svc, :user_svc_base_url)
  defp endpoints, do: Application.get_env(:image_svc, :user_svc_endpoints)

  @doc """
  Stores a PDF in user_svc (MinIO storage).

  ## Parameters
  - `pdf_binary`: The PDF file as binary
  - `user_id`: User identifier
  - `original_storage_id`: The storage ID of the original PNG
  - `user_email`: User email for notifications

  ## Returns
  - `{:ok, %Mcsv.V2.StoreImageResponse{}}` on success
  - `{:error, reason}` on failure
  """
  def store_pdf(pdf_binary, user_id, original_storage_id, user_email) do
    Logger.info(
      "[Image][UserSvcClient] Uploading PDF to storage (#{byte_size(pdf_binary)} bytes)"
    )

    request_binary =
      %Mcsv.V2.StoreImageRequest{
        image_data: pdf_binary,
        user_id: user_id,
        format: "pdf",
        original_storage_id: original_storage_id,
        user_email: user_email
      }
      |> Mcsv.V2.StoreImageRequest.encode()

    case post(user_base_url(), endpoints().store_image, request_binary) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, Mcsv.V2.StoreImageResponse.decode(body)}

      {:ok, %Req.Response{status: status}} ->
        {:error, "[Image] HTTP #{status}"}

      {:error, reason} ->
        {:error, "[Image] #{inspect(reason)}"}
    end
  end

  # Private HTTP helpers

  defp post(base, path, body) do
    case Req.post(
           Req.new(base_url: base)
           |> OpentelemetryReq.attach(propagate_trace_headers: true),
           url: path,
           body: body,
           headers: [{"content-type", "application/protobuf"}],
           receive_timeout: 30_000
         ) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end
end
