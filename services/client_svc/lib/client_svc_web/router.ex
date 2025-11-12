defmodule ClientServiceWeb.Router do
  use ClientServiceWeb, :router

  @moduledoc false

  post("/client_svc/receive_email_notification/v1", EmailNotificationController, :receive)

  post("/client_svc/pdf_ready/v1", PdfReadyController, :receive)

  get("/health", HealthController, :check)
  head("/health", HealthController, :check)
end
