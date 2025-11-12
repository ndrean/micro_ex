defmodule ImageService.Repo.Migrations.CreateConversions do
  use Ecto.Migration

  def change do
    create table(:conversions, primary_key: false) do
      add :image_url, :text, null: false
      add :job_id, :text, null: false
      add :result_url, :text
      add :status, :text, null: false, default: "processing"
      add :error_reason, :text
      add :inserted_at, :integer, null: false
      add :completed_at, :integer
    end

    # Composite primary key on (image_url, job_id)
    create unique_index(:conversions, [:image_url, :job_id], name: :conversions_pkey)

    # Index for querying by status and time
    create index(:conversions, [:status, :inserted_at])
  end
end
