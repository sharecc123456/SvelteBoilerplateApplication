defmodule BoilerPlate.Repo.Migrations.AddUsernameAndPasswordToUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :username, :string
      add :password_hash, :string
    end
  end
end
