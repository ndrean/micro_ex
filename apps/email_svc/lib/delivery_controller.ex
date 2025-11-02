defmodule DeliveryController do
  import Plug.Conn
  require Logger

  def send(conn) do
    {:ok, binary_body, conn} = Plug.Conn.read_body(conn)

    # Decode protobuf and pattern match!

    %Mcsv.EmailRequest{
      user_name: name,
      user_email: email,
      email_type: type
    } = Mcsv.EmailRequest.decode(binary_body)

    case type do
      "welcome" ->
        deliver_and_confirm(conn, "welcome", email, name)

      "notification" ->
        deliver_and_confirm(conn, "notification", email, name)

      _ ->
        conn |> send_resp(400, "Unknown email type")
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

    %Mcsv.EmailResponse{
      success: true,
      message: "Email sent to #{email}"
    }

    Logger.info("[DeliveryController]: Sent email to #{email}")

    response_binary =
      %Mcsv.EmailResponse{
        success: true,
        message: "[DeliveryController] New email sent to #{email}"
      }
      |> Mcsv.EmailResponse.encode()

    conn
    |> put_resp_content_type("application/protobuf")
    |> send_resp(200, response_binary)
  end
end
