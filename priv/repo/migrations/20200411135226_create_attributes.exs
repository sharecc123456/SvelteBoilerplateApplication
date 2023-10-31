defmodule BoilerPlate.Repo.Migrations.CreateAttributes do
  use Ecto.Migration

  def up do
    create table(:attributes) do
      add :name, :string

      timestamps()
    end

    alter table(:documents_requests) do
      add :attributes, {:array, :integer}, default: []
    end

    flush()

    BoilerPlate.Repo.insert!(%BoilerPlate.Attribute{
      id: 1,
      name: "Multiple File Upload"
    })
  end

  def down do
    drop table(:attributes)

    alter table(:documents_requests) do
      remove :attributes
    end
  end
end
