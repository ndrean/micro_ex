defmodule UserSvcWeb.Router do
  use UserSvcWeb, :router

  # No pipelines needed for protobuf APIs - direct routing

  # Health check endpoint (GET/HEAD for load balancers)
  get("/health", HealthController, :check)
  head("/health", HealthController, :check)
  # RPC-style protobuf endpoints (matches services.proto)

  # UserService.CreateUser - Create user and trigger email workflow
  post("/user_svc/create_email/v1", CreateEmailController, :create)

  # UserService.NotifyEmailSent - Receive callback from job_svc
  post("/user_svc/notify_email_sent/v1", ForwardEmailNotificationController, :forward)

  # UserService.ConvertImage - Initiate image conversion workflow
  post("/user_svc/convert_image/v1", ConvertImageController, :convert)

  # UserService.ImageLoader - Serve stored images to other services
  get("/user_svc/image_loader/v1/:job_id", ImageLoaderController, :load)

  post("/user_svc/notify_image_converted/v1", NotifyImageConvertedController, :forward)
end
