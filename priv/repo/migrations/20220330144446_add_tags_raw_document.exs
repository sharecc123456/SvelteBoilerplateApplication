defmodule BoilerPlate.Repo.Migrations.AddTagsRawDocument do
  use Ecto.Migration

  def change do
    alter table(:raw_documents) do
      add :tags, {:array, :integer}
    end
  end
end
