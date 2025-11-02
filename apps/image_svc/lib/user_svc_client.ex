defmodule ImageSvc.UserSvcClient do
  @moduledoc """
  HTTP client for communicating with user_svc.

  Centralizes all HTTP calls to user_svc endpoints with consistent
  configuration and error handling.
  """

  require Logger

  @base_url Application.compile_env(:image_svc, :user_svc_base_url)
  @endpoints Application.compile_env(:image_svc, :user_svc_endpoints)

  @doc """
  Stores a PDF in user_svc (MinIO storage).

  ## Parameters
  - `pdf_binary`: The PDF file as binary
  - `user_id`: User identifier
  - `original_storage_id`: The storage ID of the original PNG
  - `user_email`: User email for notifications

  ## Returns
  - `{:ok, %Mcsv.StoreImageResponse{}}` on success
  - `{:error, reason}` on failure
  """
  def store_pdf(pdf_binary, user_id, original_storage_id, user_email) do
    Logger.info("[UserSvcClient] Uploading PDF to storage (#{byte_size(pdf_binary)} bytes)")

    request_binary =
      %Mcsv.StoreImageRequest{
        image_data: pdf_binary,
        user_id: user_id,
        format: "pdf",
        original_storage_id: original_storage_id,
        user_email: user_email
      }
      |> Mcsv.StoreImageRequest.encode()

    case post(@base_url, @endpoints.store_image, request_binary) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, Mcsv.StoreImageResponse.decode(body)}

      {:ok, %Req.Response{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private HTTP helpers

  defp post(base, path, body) do
    try do
      response =
        Req.new(base_url: base)
        |> Req.post!(
          url: path,
          body: body,
          headers: [{"content-type", "application/protobuf"}],
          receive_timeout: 30_000
        )

      {:ok, response}
    rescue
      error ->
        {:error, error}
    end
  end
end
