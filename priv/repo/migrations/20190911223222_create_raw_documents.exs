defmodule BoilerPlate.Repo.Migrations.CreateRawDocuments do
  use Ecto.Migration

  def change do
    create table(:raw_documents) do
      add :name, :string
      add :description, :string
      add :file_name, :string
      add :company_id, references(:companies, on_delete: :nothing)

      timestamps()
    end

    create index(:raw_documents, [:company_id])
  end
end
