defmodule BoilerPlate.Repo.Migrations.AddDueDatesColumnPackageContents do
  use Ecto.Migration

  def change do
    alter table(:package_contents) do
      add :enforce_due_date, :boolean, default: false
      add :due_days, :integer, default: nil
    end
  end
end
