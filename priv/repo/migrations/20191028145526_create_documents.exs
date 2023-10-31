defmodule BoilerPlate.Repo.Migrations.CreateDocuments do
  use Ecto.Migration

  def change do
    create table(:documents) do
      add :raw_document_id, :integer
      add :company_id, :integer
      add :filename, :string
      add :recipient_id, :integer
      add :status, :integer

      timestamps()
    end

  end
end
