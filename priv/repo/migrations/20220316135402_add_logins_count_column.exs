defmodule BoilerPlate.Repo.Migrations.AddLoginsCountColumn do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :logins_count, :integer, default: 1
    end
  end
end
