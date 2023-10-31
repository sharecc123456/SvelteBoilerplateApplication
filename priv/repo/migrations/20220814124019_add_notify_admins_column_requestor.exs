defmodule BoilerPlate.Repo.Migrations.AddNotifyAdminsColumnRequestor do
  use Ecto.Migration

  def change do
    alter table(:requestors) do
      add :notify_admins, :boolean, default: false
    end
  end
end
