defmodule DeliveryController do
  use EmailServiceWeb, :controller

  @moduledoc """
  Controller for handling email delivery requests.
  1. Receives EmailRequest protobuf via HTTP POST.
  2. Decodes the protobuf to extract email details.
  3. Sends the email using EmailService.Mailer.
  4. Responds with EmailResponse protobuf indicating success or failure.
  """

  require Logger

  def send(conn, _) do
    with {:ok, binary_body, new_conn} <-
           Plug.Conn.read_body(conn),
         {:ok,
          %Mcsv.EmailRequest{
            user_name: name,
            user_email: email,
            email_type: type
          }} <-
           maybe_decode_email_request(binary_body) do
      case type do
        "welcome" ->
          deliver_and_confirm(new_conn, "welcome", email, name)

        "notification" ->
          deliver_and_confirm(new_conn, "notification", email, name)

        _ ->
          Logger.error("[Email][DeliveryController] Failed request: unknow mail type")
          send_resp(new_conn, 400, "[Email][DeliveryController] Unknown email type")
      end
    else
      {:error, :decode_error} ->
        send_resp(conn, 422, "[Email][DeliveryController] Bad Request")
    end
  end

  @doc """
  Attempts to decode the binary body into an EmailRequest protobuf.
  ## Parameters
    - binary_body: The raw binary body from the HTTP request.
  ## Returns
    - {:ok, %Mcsv.EmailRequest{}} on success
    - {:error, :decode_error} on failure

      iex> DeliveryController.maybe_decode_email_request(1)
      {:error, :decode_error}

  """

  def maybe_decode_email_request(binary_body) do
    try do
      %Mcsv.EmailRequest{} = resp = Mcsv.EmailRequest.decode(binary_body)
      {:ok, resp}
    catch
      :error, reason ->
        Logger.error("[Email][DeliveryController] Protobuf decode error: #{inspect(reason)}")
        {:error, :decode_error}
    end
  end

  defp deliver_and_confirm(conn, type, email, name) do
    case type do
      "welcome" ->
        EmailService.Emails.UserEmail.welcome_email(email, name)
        |> EmailService.Mailer.deliver()

      "notification" ->
        EmailService.Emails.UserEmail.notification_email(
          email,
          name,
          "new notification",
          "a notification"
        )
        |> EmailService.Mailer.deliver()
    end

    Logger.info("[Email][DeliveryController]: New email sent to #{email}")

    response_binary =
      %Mcsv.EmailResponse{
        success: true,
        message: "[Email][DeliveryController] New email sent to #{email}"
      }
      |> Mcsv.EmailResponse.encode()

    conn
    |> put_resp_content_type("application/protobuf")
    |> send_resp(200, response_binary)
  end
end
