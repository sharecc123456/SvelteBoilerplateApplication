defmodule BoilerPlate.Repo.Migrations.AddChecklistExpireColumn do
  use Ecto.Migration

  def change do
    alter table(:package_assignments) do
      add :due_date_expired, :boolean, default: false
    end
  end
end
