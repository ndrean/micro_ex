defmodule ImageSvcWeb.Router do
  use ImageSvcWeb, :router

  # No pipelines needed for protobuf APIs - direct routing

  # ImageService.ConvertImage - Convert image to PDF using ImageMagick
  post("/image_svc/convert_image/v1", ConversionController, :convert)

  # Health check endpoint (GET/HEAD for load balancers)
  get("/health", HealthController, :check)
  head("/health", HealthController, :check)
  # OpenAPI documentation endpoints
  get("/api/openapi", OpenApiController, :spec)
  get("/swaggerui", SwaggerController, :ui)
end
