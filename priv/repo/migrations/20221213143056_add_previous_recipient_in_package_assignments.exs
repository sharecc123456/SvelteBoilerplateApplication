defmodule BoilerPlate.Repo.Migrations.AddPreviousRecipientInPackageAssignments do
  use Ecto.Migration

  def change do
    alter table(:package_assignments) do
      add :deleted_recipient_id, :integer, default: -1
    end
  end
end
