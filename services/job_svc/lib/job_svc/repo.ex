defmodule JobService.Repo do
  use Ecto.Repo,
    otp_app: :job_svc,
    adapter: Ecto.Adapters.SQLite3
end
