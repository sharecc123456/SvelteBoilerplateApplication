defmodule BoilerPlate.Repo.Migrations.AddDueDatesColumnPackage do
  use Ecto.Migration

  def change do
    alter table(:packages) do
      add :enforce_due_date, :boolean, default: false
      add :due_days, :integer, default: nil
      add :due_date_type, :integer, default: nil
    end
  end
end
