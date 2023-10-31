defmodule BoilerPlate.Repo.Migrations.UpdateRequestorsWeeklyDigest do
  use Ecto.Migration

  def change do
    alter table(:requestors) do
      add :weekly_digest, :boolean, default: false
    end
  end
end
