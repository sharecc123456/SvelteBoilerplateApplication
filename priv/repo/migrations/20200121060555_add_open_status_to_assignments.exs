defmodule BoilerPlate.Repo.Migrations.AddOpenStatusToAssignments do
  use Ecto.Migration

  def change do
    alter table(:package_assignments) do
      add :open_status, :integer, default: 0
    end
  end
end
