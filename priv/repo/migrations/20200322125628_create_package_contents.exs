defmodule BoilerPlate.Repo.Migrations.CreatePackageContents do
  use Ecto.Migration

  def change do
    create table(:package_contents) do
      add :package_id, :integer
      add :status, :integer
      add :documents, {:array, :integer}
      add :requests, {:array, :integer}

      timestamps()
    end

  end
end
