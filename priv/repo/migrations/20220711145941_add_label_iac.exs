defmodule BoilerPlate.Repo.Migrations.AddIACLabel do
  use Ecto.Migration

  def change do
    alter table(:iac_field) do
      add :label, :string, default: ""
    end
  end
end
