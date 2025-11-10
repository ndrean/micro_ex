defmodule EmailService.Mailer do
  use Swoosh.Mailer, otp_app: :email_svc
  @moduledoc false
end
