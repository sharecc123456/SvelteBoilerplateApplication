defmodule BoilerPlate.Repo.Migrations.AddTagsColumnPkgContents do
  use Ecto.Migration

  def change do
    alter table(:package_contents) do
      add :tags, {:array, :integer}, default: []
    end
  end
end
