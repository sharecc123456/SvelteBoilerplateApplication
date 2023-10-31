defmodule BoilerPlate.Repo.Migrations.AddTagsColumnPackages do
  use Ecto.Migration

  def change do
    alter table(:packages) do
      add :tags, {:array, :integer}, default: []
    end
  end
end
