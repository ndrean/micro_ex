defmodule EmailSenderController do
  use JobServiceWeb, :controller
  require Logger
  @moduledoc false

  def enqueue(conn, _) do
    {:ok, binary_body, conn} = Plug.Conn.read_body(conn)

    # # Decode protobuf and pattern match!
    email_params =
      Mcsv.V2.UserRequest.decode(binary_body)

    %Mcsv.V2.UserRequest{type: type, email: email} = email_params

    case injob_email(email_params) do
      {:ok, %Oban.Job{} = _oban_job_id} ->
        response_binary =
          encode_binary_message(
            "[Job][EmailSenderController]#{type} email enqueued for  #{email}",
            true
          )

        Logger.info("[Job][EmailSenderController]Worker: Enqueued welcome email to user #{email}")

        conn
        |> put_resp_content_type("application/protobuf")
        |> send_resp(200, response_binary)

      {:error, reason} ->
        Logger.error(
          "[Job][EmailSenderController] Failed to enqueue email job: #{inspect(reason)}"
        )

        response_binary =
          encode_binary_message(
            "[Job][EmailSenderController] #{type} email FAILED for  #{email}",
            false
          )

        conn
        |> put_resp_content_type("application/protobuf")
        |> send_resp(500, response_binary)
    end
  end

  @spec encode_binary_message(String.t(), boolean()) :: binary()
  def encode_binary_message(message, bool) do
    %Mcsv.V2.UserResponse{
      message: message,
      ok: bool
    }
    |> Mcsv.V2.UserResponse.encode()
  end

  @spec injob_email(map()) :: {:ok, Oban.Job.t()} | {:error, any()}
  defp injob_email(%{type: type_enum} = params)
       when type_enum in [:EMAIL_TYPE_WELCOME, :EMAIL_TYPE_NOTIFICATION] do
    # Inject OpenTelemetry trace context transformed into a map to the job args
    trace_headers = :otel_propagator_text_map.inject([])
    trace_context = Map.new(trace_headers)

    # Convert enum to string for Oban storage
    type_string = enum_to_string(type_enum)

    changeset =
      %{
        "id" => params.id,
        "email" => params.email,
        "name" => params.name,
        "type" => type_string,
        "_otel_trace_context" => trace_context
      }
      |> JobService.Workers.EmailWorker.new()

    case changeset.valid? do
      true -> Oban.insert(changeset)
      false -> {:error, inspect(changeset.errors)}
    end
  end

  # Convert EmailType enum to string for Oban job storage
  defp enum_to_string(:EMAIL_TYPE_WELCOME), do: "welcome"
  defp enum_to_string(:EMAIL_TYPE_NOTIFICATION), do: "notification"
end
