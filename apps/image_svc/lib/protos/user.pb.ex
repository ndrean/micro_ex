defmodule Mcsv.UserRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :id, 1, type: :string
  field :name, 2, type: :string
  field :email, 3, type: :string
  field :bio, 4, type: :string
  field :type, 5, type: :string
end

defmodule Mcsv.UserResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :ok, 1, type: :bool
  field :message, 2, type: :string
end

defmodule Mcsv.StoreImageRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :image_data, 1, type: :bytes, json_name: "imageData"
  field :user_id, 2, type: :string, json_name: "userId"
  field :format, 3, type: :string
  field :original_storage_id, 4, type: :string, json_name: "originalStorageId"
  field :user_email, 5, type: :string, json_name: "userEmail"
end

defmodule Mcsv.StoreImageResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :success, 1, type: :bool
  field :message, 2, type: :string
  field :storage_id, 3, type: :string, json_name: "storageId"
  field :presigned_url, 4, type: :string, json_name: "presignedUrl"
  field :size, 5, type: :int64
end

defmodule Mcsv.PdfReadyNotification do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :user_email, 1, type: :string, json_name: "userEmail"
  field :storage_id, 2, type: :string, json_name: "storageId"
  field :presigned_url, 3, type: :string, json_name: "presignedUrl"
  field :size, 4, type: :int64
  field :message, 5, type: :string
end

defmodule Mcsv.PdfReadyResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :ok, 1, type: :bool
  field :message, 2, type: :string
end
