defmodule EmailService.Emails.UserEmail do
  import Swoosh.Email

  @from {"Email Service", "noreply@example.com"}

  def welcome_email(to_email, user_name) do
    new()
    |> to(to_email)
    |> from(@from)
    |> subject("Welcome to our service!")
    |> html_body("<h1>Welcome #{user_name}!</h1><p>Thank you for joining us.</p>")
    |> text_body("Welcome #{user_name}! Thank you for joining us.")
  end

  def notification_email(to_email, user_name, subject, body) do
    new()
    |> to(to_email)
    |> from(@from)
    |> subject(subject)
    |> html_body("<h1>Hello #{user_name}</h1><p>#{body}</p>")
    |> text_body("Hello #{user_name}\n\n#{body}")
  end

  def user_updated_email(to_email, user_name) do
    new()
    |> to(to_email)
    |> from(@from)
    |> subject("Your profile has been updated")
    |> html_body("<h1>Hi #{user_name}</h1><p>Your profile has been successfully updated.</p>")
    |> text_body("Hi #{user_name}\n\nYour profile has been successfully updated.")
  end
end
