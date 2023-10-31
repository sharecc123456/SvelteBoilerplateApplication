defmodule BoilerPlate.Repo.Migrations.CreateRecipientsData do
  use Ecto.Migration

  def change do
    create table(:recipients_data) do
      add :status, :integer
      add :flags, :integer
      add :label, :string
      add :value, :map
      add :recipient_id, references(:recipients, on_delete: :nothing)

      timestamps()
    end

    create index(:recipients_data, [:recipient_id])
  end
end
