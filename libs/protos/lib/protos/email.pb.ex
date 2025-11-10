defmodule Mcsv.EmailRequest.VariablesEntry do
  @moduledoc false

  use Protobuf, map: true, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :key, 1, type: :string
  field :value, 2, type: :string
end

defmodule Mcsv.EmailRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :user_id, 1, type: :string, json_name: "userId"
  field :user_name, 2, type: :string, json_name: "userName"
  field :user_email, 3, type: :string, json_name: "userEmail"
  field :email_type, 4, type: :string, json_name: "emailType"
  field :variables, 5, repeated: true, type: Mcsv.EmailRequest.VariablesEntry, map: true
end

defmodule Mcsv.EmailResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.15.0", syntax: :proto3

  field :success, 1, type: :bool
  field :message, 2, type: :string
  field :email_id, 3, type: :string, json_name: "emailId"
  field :timestamp, 4, type: :int64
end
