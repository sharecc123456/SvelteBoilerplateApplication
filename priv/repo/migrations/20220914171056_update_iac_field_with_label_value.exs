defmodule BoilerPlate.Repo.Migrations.UpdateIacFieldWithLabelValue do
  use Ecto.Migration

  def change do
    alter table(:iac_field) do
      add :label_value, :string, default: nil
    end
  end
end
