defmodule Mcsv.ImageConversionRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :user_id, 1, type: :string, json_name: "userId"
  field :user_email, 2, type: :string, json_name: "userEmail"
  field :image_url, 3, type: :string, json_name: "imageUrl"
  field :image_data, 9, type: :bytes, json_name: "imageData"
  field :input_format, 4, type: :string, json_name: "inputFormat"
  field :pdf_quality, 5, type: :string, json_name: "pdfQuality"
  field :strip_metadata, 6, type: :bool, json_name: "stripMetadata"
  field :max_width, 7, type: :int32, json_name: "maxWidth"
  field :max_height, 8, type: :int32, json_name: "maxHeight"
  field :storage_id, 10, type: :string, json_name: "storageId"
end

defmodule Mcsv.ImageConversionResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :success, 1, type: :bool
  field :message, 2, type: :string
  field :pdf_data, 3, type: :bytes, json_name: "pdfData"
  field :input_size, 4, type: :int64, json_name: "inputSize"
  field :output_size, 5, type: :int64, json_name: "outputSize"
  field :width, 6, type: :int32
  field :height, 7, type: :int32
  field :storage_id, 8, type: :string, json_name: "storageId"
  field :original_storage_id, 9, type: :string, json_name: "originalStorageId"
  field :pdf_url, 10, type: :string, json_name: "pdfUrl"
  field :user_email, 11, type: :string, json_name: "userEmail"
end
