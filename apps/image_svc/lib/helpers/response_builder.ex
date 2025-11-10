defmodule ImageSvc.ResponseBuilder do
  @moduledoc """
  Builds protobuf response messages for image conversion operations.

  Centralizes the creation of ImageConversionResponse messages for
  success and failure cases.
  """

  @doc """
  Builds an acknowledgment response for the job worker.

  This is sent immediately to job_svc to acknowledge receipt.

  ## Parameters
  - `image_info`: Map with :size, :width, :height keys
  - `output_size`: Size of the converted PDF in bytes
  - `pdf_url`: MinIO/S3 URL where the PDF is stored
  - `storage_id`: S3 key for the PDF
  - `original_storage_id`: Original PNG storage ID (for cleanup)
  - `user_email`: User who initiated the conversion

  ## Returns
  Encoded ImageConversionResponse binary
  """
  def build_ack_response(
        image_info,
        output_size,
        pdf_url,
        storage_id,
        original_storage_id,
        user_email
      ) do
    %Mcsv.ImageConversionResponse{
      success: true,
      message: "Conversion completed",
      pdf_data: <<>>,
      input_size: image_info.size,
      output_size: output_size,
      width: image_info.width,
      height: image_info.height,
      storage_id: storage_id,
      original_storage_id: original_storage_id,
      pdf_url: pdf_url,
      user_email: user_email
    }
    |> Mcsv.ImageConversionResponse.encode()
  end

  @doc """
  Builds a failure response.

  ## Parameters
  - `reason`: Error reason string

  ## Returns
  Encoded ImageConversionResponse binary
  """
  def build_failure_response(reason) do
    %Mcsv.ImageConversionResponse{
      success: false,
      message: "Conversion failed: #{reason}",
      pdf_data: <<>>,
      input_size: 0,
      output_size: 0,
      width: 0,
      height: 0
    }
    |> Mcsv.ImageConversionResponse.encode()
  end
end
