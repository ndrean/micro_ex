defmodule EmailSenderController do
  import Plug.Conn
  require Logger
  @moduledoc false

  @spec enqueue(Plug.Conn.t()) :: Plug.Conn.t()
  def enqueue(conn) do
    {:ok, binary_body, conn} = Plug.Conn.read_body(conn)

    # # Decode protobuf and pattern match!
    email_params =
      Mcsv.UserRequest.decode(binary_body)

    %Mcsv.UserRequest{type: type, email: email} = email_params

    Logger.info("[Job][EmailSenderController]Worker: Enqueued welcome email to user #{email}")

    case injob_email(email_params) do
      {:ok, %Oban.Job{} = _oban_job_id} ->
        response_binary =
          encode_binary_message(
            "[EmailSenderController]#{type} email enqueued for  #{email}",
            true
          )

        conn
        |> put_resp_content_type("application/protobuf")
        |> send_resp(200, response_binary)

      {:error, reason} ->
        Logger.error(
          "[Job][EmailSenderController] Failed to enqueue email job: #{inspect(reason)}"
        )

        response_binary =
          encode_binary_message("#{type} email FAILED for  #{email}", false)

        conn
        |> put_resp_content_type("application/protobuf")
        |> send_resp(500, response_binary)
    end
  end

  @spec encode_binary_message(String.t(), boolean()) :: binary()
  def encode_binary_message(message, bool) do
    %Mcsv.UserResponse{
      message: message,
      ok: bool
    }
    |> Mcsv.UserResponse.encode()
  end

  @spec injob_email(map()) :: {:ok, Oban.Job.t()} | {:error, any()}
  defp injob_email(%{type: "welcome"} = params) do
    %{
      "id" => params.id,
      "email" => params.email,
      "name" => params.name,
      "bio" => params.bio,
      "type" => params.type
    }
    |> JobService.Workers.EmailWorker.new()
    |> Oban.insert()
  end
end
