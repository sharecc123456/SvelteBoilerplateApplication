defmodule BoilerPlate.Repo.Migrations.AddRequestorToAssignments do
  use Ecto.Migration

  def change do
    alter table(:package_assignments) do
      add :requestor_id, :integer, default: 0
    end
  end
end
