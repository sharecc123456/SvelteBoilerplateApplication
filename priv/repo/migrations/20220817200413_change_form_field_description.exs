defmodule BoilerPlate.Repo.Migrations.ChangeFormFieldDescription do
  use Ecto.Migration

  def change do
    alter table(:form_fields) do
      modify :description, :text, default: "-"
    end
  end
end
