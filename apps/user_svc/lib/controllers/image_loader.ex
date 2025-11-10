defmodule ImageLoaderController do
  @moduledoc """
  Serves stored images to other services (like image_svc).

  Endpoint: GET /user_svc/ImageLoader/:job_id
  """

  use UserSvcWeb, :controller
  require Logger
  import Plug.Conn

  def load(conn, %{"job_id" => job_id}) do
    case ImageStorage.fetch(job_id) do
      {:ok, image_binary} ->
        # Extract format from storage_id extension (e.g., "123_abc.png" -> "png")
        format = job_id |> Path.extname() |> String.trim_leading(".")
        content_type = get_content_type(format)

        Logger.info(
          "[User][ImageLoaderController] Serving image #{job_id} (#{byte_size(image_binary)} bytes, #{format})"
        )

        conn
        |> put_resp_content_type(content_type)
        |> put_resp_header("content-length", to_string(byte_size(image_binary)))
        |> send_resp(200, image_binary)

      {:error, :not_found} ->
        Logger.warning("[User][ImageLoaderController] Image #{job_id} not found")

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(404, Jason.encode!(%{error: "[User] Image not found"}))
    end
  end

  defp get_content_type("png"), do: "image/png"
  defp get_content_type("jpg"), do: "image/jpeg"
  defp get_content_type("jpeg"), do: "image/jpeg"
  defp get_content_type("gif"), do: "image/gif"
  defp get_content_type(_), do: "application/octet-stream"
end
