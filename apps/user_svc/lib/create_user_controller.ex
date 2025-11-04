defmodule CreateUserController do
  @moduledoc """
  Handles user creation and triggers welcome email.

  Flow:
  1. Receives user creation request
  2. Enqueues welcome email job via job_svc
  3. Returns acknowledgment to client
  """

  require Logger
  import Plug.Conn

  def create(conn) do
    with {:ok, binary_body, new_conn} <-
           read_body(conn),
         {:ok, resp_binary} <-
           Clients.JobSvcClient.enqueue_email(binary_body) do
      new_conn
      |> put_resp_content_type("application/protobuf")
      |> send_resp(200, resp_binary)
    else
      {:error, reason} ->
        conn
        |> send_resp(500, reason)
    end
  end
end
