defmodule BoilerPlate.Repo.Migrations.AddDueDateToAssignments do
  use Ecto.Migration

  def change do
    alter table(:package_assignments) do
      add :due_date, :utc_datetime
      add :enforce_due_date, :boolean, default: false
    end
  end
end
