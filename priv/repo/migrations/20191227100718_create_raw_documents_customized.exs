defmodule BoilerPlate.Repo.Migrations.CreateRawDocumentsCustomized do
  use Ecto.Migration

  def change do
    create table(:raw_documents_customized) do
      add :recipient_id, :integer
      add :raw_document_id, :integer
      add :file_name, :string
      add :flags, :integer
      add :status, :integer

      timestamps()
    end

  end
end
