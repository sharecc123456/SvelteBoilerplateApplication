defmodule BoilerPlate.Repo.Migrations.UpdateUsersAuthenticatorApp do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :two_factor_data, :map, default: %{}
    end
  end
end
