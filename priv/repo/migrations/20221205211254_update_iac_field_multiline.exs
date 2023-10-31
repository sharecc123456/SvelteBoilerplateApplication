defmodule BoilerPlate.Repo.Migrations.UpdateIacFieldMultiline do
  use Ecto.Migration

  def change do
    alter table(:iac_field) do
      add :allow_multiline, :boolean, default: false
    end
  end
end
