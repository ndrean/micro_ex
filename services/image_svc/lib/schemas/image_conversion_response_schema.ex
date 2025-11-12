defmodule ImageSvc.Schemas.ImageConversionResponseSchema do
  @moduledoc """
  OpenAPI schema for ImageConversionResponse (protobuf message).
  """

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ImageConversionResponse",
    description: "Response after image conversion",
    type: :object,
    properties: %{
      success: %Schema{type: :boolean, description: "Whether conversion succeeded"},
      message: %Schema{type: :string, description: "Status message"},
      pdf_data: %Schema{
        type: :string,
        format: :byte,
        description: "Converted PDF binary data"
      },
      input_size: %Schema{
        type: :integer,
        format: :int64,
        description: "Original image size in bytes"
      },
      output_size: %Schema{
        type: :integer,
        format: :int64,
        description: "PDF size in bytes"
      },
      width: %Schema{type: :integer, format: :int32, description: "Image width in pixels"},
      height: %Schema{type: :integer, format: :int32, description: "Image height in pixels"},
      storage_id: %Schema{type: :string, description: "PDF storage identifier"},
      original_storage_id: %Schema{
        type: :string,
        description: "Original PNG storage identifier (for cleanup)"
      }
    },
    example: %{
      "success" => true,
      "message" => "Conversion successful",
      "input_size" => 524_288,
      "output_size" => 102_400,
      "width" => 1920,
      "height" => 1080,
      "storage_id" => "pdf_xyz789",
      "original_storage_id" => "img_abc123"
    }
  })
end
