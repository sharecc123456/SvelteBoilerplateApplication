defmodule BoilerPlate.Repo.Migrations.AddSigneeVersionToIacsig do
  use Ecto.Migration

  def change do
    alter table(:iac_signatures) do
      add :signee_version, :integer, default: 0
      add :signee_type, :integer, default: 0
      add :signee_id, :integer, default: 0
    end
  end
end
