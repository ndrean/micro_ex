defmodule ImageSvc.Schemas.ImageConversionRequestSchema do
  @moduledoc """
  OpenAPI schema for ImageConversionRequest (protobuf message).
  """

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ImageConversionRequest",
    description: "Request to convert an image (PNG/JPEG) to PDF",
    type: :object,
    required: [:user_id, :user_email, :input_format],
    properties: %{
      user_id: %Schema{type: :string, description: "User identifier"},
      user_email: %Schema{type: :string, format: :email, description: "User email address"},
      image_url: %Schema{
        type: :string,
        format: :uri,
        description: "URL to fetch image from (preferred)",
        example: "http://user_svc:8081/user_svc/ImageLoader/job_123"
      },
      image_data: %Schema{
        type: :string,
        format: :byte,
        description: "Raw image binary data (deprecated, use image_url)"
      },
      input_format: %Schema{
        type: :string,
        enum: ["png", "jpeg", "jpg"],
        description: "Input image format"
      },
      pdf_quality: %Schema{
        type: :string,
        enum: ["low", "medium", "high", "lossless"],
        default: "medium",
        description: "PDF conversion quality"
      },
      strip_metadata: %Schema{
        type: :boolean,
        default: false,
        description: "Remove EXIF metadata from image"
      },
      max_width: %Schema{
        type: :integer,
        format: :int32,
        default: 0,
        description: "Maximum width in pixels (0 = no resize)"
      },
      max_height: %Schema{
        type: :integer,
        format: :int32,
        default: 0,
        description: "Maximum height in pixels (0 = no resize)"
      },
      storage_id: %Schema{
        type: :string,
        description: "Unique storage identifier for cleanup"
      }
    },
    example: %{
      "user_id" => "user_123",
      "user_email" => "user@example.com",
      "image_url" => "http://user_svc:8081/user_svc/ImageLoader/job_456",
      "input_format" => "png",
      "pdf_quality" => "high",
      "strip_metadata" => true,
      "max_width" => 1920,
      "max_height" => 1080,
      "storage_id" => "img_abc123"
    }
  })
end
