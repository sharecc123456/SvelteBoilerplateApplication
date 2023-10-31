defmodule BoilerPlate.Repo.Migrations.CreateHackTable do
  use Ecto.Migration

  def change do
    create table(:experimental_hacks) do
      add :ticket_id, :integer
      add :data, :text

      timestamps()
    end
  end
end
