defmodule ImageService.Repo do
  use Ecto.Repo,
    otp_app: :image_svc,
    adapter: Ecto.Adapters.SQLite3
end
