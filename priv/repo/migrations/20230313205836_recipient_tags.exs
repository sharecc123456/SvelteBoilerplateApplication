defmodule BoilerPlate.Repo.Migrations.RecipientTags do
  use Ecto.Migration

  def up do
    create table(:recipient_tags) do
      add :name, :string
      add :company_id, references(:companies, on_delete: :nothing)
      add :color, :string
      add :status, :integer
      add :sensitive_level, :integer, default: 1

      timestamps()
    end

    create index(:recipient_tags, [:company_id])

    flush()

    alter table(:recipients) do
      add :tags, {:array, :integer}, default: []
    end
  end

  def down do
    drop table(:recipient_tags)

    alter table(:recipients) do
      remove :tags
    end
  end
end
