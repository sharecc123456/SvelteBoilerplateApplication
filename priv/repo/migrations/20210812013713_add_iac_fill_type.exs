defmodule BoilerPlate.Repo.Migrations.AddIacFillType do
  use Ecto.Migration

  def change do
    alter table(:iac_field) do
      add :fill_type, :integer, default: 0
    end
  end
end
