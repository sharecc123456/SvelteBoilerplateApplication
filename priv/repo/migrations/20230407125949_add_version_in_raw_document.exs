defmodule BoilerPlate.Repo.Migrations.AddVersionInRawDocument do
  use Ecto.Migration

  def change do
    alter table(:raw_documents) do
      add :version, :integer, default: 0
    end
  end
end
