defmodule BoilerPlate.Repo.Migrations.AddTemplateArchivedFlag do
  use Ecto.Migration

  def change do
    alter table(:raw_documents) do
      add :is_archived, :boolean, default: false
    end
  end
end
