defmodule BoilerPlate.Repo.Migrations.AddDocumentVersionColumn do
  use Ecto.Migration

  def change do
    alter table(:raw_documents_customized) do
      add :version, :integer, default: 1
    end
  end
end
