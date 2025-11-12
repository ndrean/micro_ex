defmodule JobServiceWeb.Router do
  use JobServiceWeb, :router

  # JobService.EnqueueEmail - Enqueue email job in Oban
  post("/job_svc/enqueue_email/v1", EmailSenderController, :enqueue)

  # JobService.ConvertImage - Enqueue image conversion job
  post("/job_svc/convert_image/v1", ImageController, :convert)

  # Health check endpoint (GET/HEAD for load balancers)
  get("/health", HealthController, :check)
  head("/health", HealthController, :check)
end
