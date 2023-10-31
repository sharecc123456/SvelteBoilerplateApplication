defmodule BoilerPlate.Repo.Migrations.ModifyFormFieldTile do
  use Ecto.Migration

  def change do
    alter table(:form_fields) do
      modify :title, :string, size: 400
    end
  end
end

