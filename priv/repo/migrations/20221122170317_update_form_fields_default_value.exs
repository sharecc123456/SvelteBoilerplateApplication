defmodule BoilerPlate.Repo.Migrations.UpdateFormFieldsDefaultValue do
  use Ecto.Migration

  def change do
    alter table(:form_fields) do
      add :default_value, :map, default: %{}
    end

    alter table(:forms) do
      add :repeat_entry_default_value, :map, default: %{}
    end

    alter table(:iac_field) do
      add :repeat_entry_form_id, references(:forms, on_delete: :nothing)
    end
  end
end
