defmodule BoilerPlate.Repo.Migrations.CreateAdhocLinks do
  use Ecto.Migration

  def change do
    create table(:adhoc_links) do
      add :type, :integer
      add :type_id, :integer
      add :adhoc_string, :string
      add :status, :integer
      add :flags, :integer

      timestamps()
    end

  end
end
