defmodule BoilerPlate.Repo.Migrations.CreatePackageAssignments do
  use Ecto.Migration

  def change do
    create table(:package_assignments) do
      add :recipient_id, :integer
      add :company_id, :integer
      add :package_id, :integer
      add :flags, :integer
      add :status, :integer

      timestamps()
    end

  end
end
