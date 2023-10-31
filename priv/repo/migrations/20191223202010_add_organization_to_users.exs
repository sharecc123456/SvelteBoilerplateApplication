defmodule BoilerPlate.Repo.Migrations.AddOrganizationToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :organization, :string, default: nil
    end
  end
end
