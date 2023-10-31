defmodule BoilerPlate.Repo.Migrations.AddTypeToTemplates do
  use Ecto.Migration

  def change do
    alter table(:raw_documents) do
      add :type, :integer
    end
  end
end
