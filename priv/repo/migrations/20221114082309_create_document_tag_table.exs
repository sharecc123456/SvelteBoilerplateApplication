defmodule BoilerPlate.Repo.Migrations.CreateDocumentTagTable do
  use Ecto.Migration

  def change do
    create table(:document_tag) do
      add :name, :string
      add :company_id, references(:companies, on_delete: :nothing)
      add :color, :string
      add :status, :integer
      add :sensitive_level, :integer, default: 1

      timestamps()
    end

    create index(:document_tag, [:company_id])

  end

  def down do
    drop table(:document_tag)
  end
end
