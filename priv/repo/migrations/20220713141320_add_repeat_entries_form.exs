defmodule BoilerPlate.Repo.Migrations.AddRepeatEntriesForm do
  use Ecto.Migration

  def change do
    alter table(:forms) do
      add :has_repeat_entries, :boolean, default: false
      add :has_repeat_vertical, :boolean, default: false
      add :repeat_label, :string, default: ""
    end
  end
end
