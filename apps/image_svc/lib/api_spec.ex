defmodule ImageSvc.ApiSpec do
  @moduledoc """
  OpenAPI specification for Image Service.

  This module generates the OpenAPI 3.0 spec from controller annotations.
  """

  alias OpenApiSpex.{Info, OpenApi, Server}
  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      servers: [
        %Server{url: "http://localhost:8084", description: "Local development"}
      ],
      info: %Info{
        title: "Image Service API",
        version: "1.0.0",
        description: """
        Microservice for image to PDF conversion.

        ## Features
        - Convert PNG/JPEG to PDF
        - Quality control (low, medium, high, lossless)
        - Metadata stripping
        - Image resizing
        - Automatic storage in MinIO via user_svc

        ## Architecture
        This service is part of a microservices architecture:
        - **user_svc** (port 8081) - Orchestration & storage
        - **job_svc** (port 8082) - Async job queue
        - **image_svc** (port 8084) - Image processing
        """
      },
      # Manually define paths (Plug.Router doesn't have __routes__ like Phoenix)
      paths: paths()
    }
    # Discover schemas from modules that use OpenApiSpex.Schema
    |> OpenApiSpex.resolve_schema_modules()
  end

  # Define paths manually since we're using Plug.Router
  defp paths do
    alias OpenApiSpex.{Operation, PathItem, RequestBody, MediaType, Response, Reference}

    %{
      "/image_svc/ConvertImage" => %PathItem{
        post: %Operation{
          operationId: "ImageSvc.ConversionController.convert",
          summary: "Convert image to PDF",
          description: """
          Converts a PNG or JPEG image to PDF format with configurable quality settings.

          **Workflow:**
          1. Fetches image from provided URL
          2. Converts to PDF using ImageMagick
          3. Stores PDF in MinIO via user_svc
          4. Returns acknowledgment with image metadata

          **Note:** Client notification is handled automatically by user_svc after storage.
          """,
          tags: ["Image Conversion"],
          requestBody: %RequestBody{
            description: "Image conversion request",
            required: true,
            content: %{
              "application/x-protobuf" => %MediaType{
                schema: %Reference{"$ref": "#/components/schemas/ImageConversionRequestSchema"}
              }
            }
          },
          responses: %{
            200 => %Response{
              description: "Conversion successful",
              content: %{
                "application/x-protobuf" => %MediaType{
                  schema: %Reference{"$ref": "#/components/schemas/ImageConversionResponseSchema"}
                }
              }
            },
            500 => %Response{
              description: "Conversion failed",
              content: %{
                "application/x-protobuf" => %MediaType{
                  schema: %Reference{"$ref": "#/components/schemas/ImageConversionResponseSchema"}
                }
              }
            }
          }
        }
      }
    }
  end
end
