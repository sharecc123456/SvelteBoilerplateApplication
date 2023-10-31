defmodule BoilerPlate.Repo.Migrations.UpdateUsersWithApiKey do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :api_key, :string, default: nil
    end
  end
end
