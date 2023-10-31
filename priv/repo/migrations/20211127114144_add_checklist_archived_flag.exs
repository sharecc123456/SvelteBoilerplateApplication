defmodule BoilerPlate.Repo.Migrations.AddChecklistArchivedFlag do
  use Ecto.Migration

  def change do
    alter table(:packages) do
      add :is_archived, :boolean, default: false
    end
  end
end
