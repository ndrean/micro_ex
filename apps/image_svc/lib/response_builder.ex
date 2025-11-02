defmodule ImageSvc.ResponseBuilder do
  @moduledoc """
  Builds protobuf response messages for image conversion operations.

  Centralizes the creation of ImageConversionResponse messages for
  success and failure cases.
  """

  @doc """
  Builds a success response after conversion completes.

  ## Parameters
  - `store_response`: The StoreImageResponse from user_svc
  - `original_storage_id`: The original PNG storage ID
  - `output_size`: Size of the converted PDF in bytes
  - `image_info`: Map with :size, :width, :height keys

  ## Returns
  Encoded ImageConversionResponse binary
  """
  def build_success_response(store_response, original_storage_id, output_size, image_info) do
    %Mcsv.ImageConversionResponse{
      success: true,
      message: store_response.message,
      pdf_data: <<>>,
      input_size: image_info.size,
      output_size: output_size,
      width: image_info.width,
      height: image_info.height,
      storage_id: store_response.storage_id,
      original_storage_id: original_storage_id
    }
    |> Mcsv.ImageConversionResponse.encode()
  end

  @doc """
  Builds an acknowledgment response for the job worker.

  This is sent immediately to job_svc to acknowledge receipt.

  ## Parameters
  - `image_info`: Map with :size, :width, :height keys
  - `output_size`: Size of the converted PDF in bytes

  ## Returns
  Encoded ImageConversionResponse binary
  """
  def build_ack_response(image_info, output_size) do
    %Mcsv.ImageConversionResponse{
      success: true,
      message: "Conversion completed, result sent to user_svc",
      pdf_data: <<>>,
      input_size: image_info.size,
      output_size: output_size,
      width: image_info.width,
      height: image_info.height
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
