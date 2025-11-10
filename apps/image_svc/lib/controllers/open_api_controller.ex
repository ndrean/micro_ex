defmodule OpenApiController do
  @moduledoc """
  OpenAPI specification endpoint.
  """

  use ImageSvcWeb, :controller

  def spec(conn, _params) do
    conn
    |> put_resp_content_type("application/json")
    |> json(ImageSvc.ApiSpec.spec())
  end
end
