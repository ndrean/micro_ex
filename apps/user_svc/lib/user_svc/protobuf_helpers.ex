defmodule ProtobufHelpers do
  @moduledoc """
  Helper functions for encoding protobuf responses.

  Centralizes response building to keep controllers clean.
  """

  @doc """
  Builds a StoreImageResponse for successful storage.
  """
  def build_store_success(format, storage_id, presigned_url, size) do
    %Mcsv.StoreImageResponse{
      success: true,
      message: "[User] #{format} stored successfully",
      storage_id: storage_id,
      presigned_url: presigned_url,
      size: size
    }
    |> Mcsv.StoreImageResponse.encode()
  end

  @doc """
  Builds a StoreImageResponse for storage failure.
  """
  def build_store_failure(reason) do
    %Mcsv.StoreImageResponse{
      success: false,
      message: "[User] Storage failed: #{inspect(reason)}",
      storage_id: "",
      presigned_url: "",
      size: 0
    }
    |> Mcsv.StoreImageResponse.encode()
  end

  @doc """
  Builds a UserResponse for successful operations.
  """
  def build_user_success(message) do
    %Mcsv.UserResponse{
      ok: true,
      message: message
    }
    |> Mcsv.UserResponse.encode()
  end

  @doc """
  Builds a UserResponse for failed operations.
  """
  def build_user_failure(message) do
    %Mcsv.UserResponse{
      ok: false,
      message: message
    }
    |> Mcsv.UserResponse.encode()
  end
end
