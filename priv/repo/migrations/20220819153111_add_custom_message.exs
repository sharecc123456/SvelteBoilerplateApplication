defmodule BoilerPlate.Repo.Migrations.AddCustomMessage do
  use Ecto.Migration

  def change do
    alter table(:package_assignments) do
      add :append_note, :string, default: ""
    end
  end
end
