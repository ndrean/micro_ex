defmodule CreateEmailController do
  @moduledoc """
  Handles email creation

  Flow:
  1. Receives email/user creation request
  2. Enqueues email job via job_svc
  3. Returns acknowledgment to client
  """

  use UserSvcWeb, :controller

  require Logger
  import Plug.Conn

  def create(conn, _) do
    with {:ok, binary_body, new_conn} <-
           read_body(conn),
         {:ok, resp_binary} <-
           Clients.JobSvcClient.enqueue_email(binary_body) do
      new_conn
      |> put_resp_content_type("application/protobuf")
      |> send_resp(200, resp_binary)
    else
      {:error, reason} ->
        Logger.error(reason)
        resp(conn, 500, "")
    end
  end
end
