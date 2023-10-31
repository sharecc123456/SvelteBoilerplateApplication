defmodule BoilerPlate.Repo.Migrations.UpdateFormFieldsAddOrder do
  use Ecto.Migration

  def change do
    alter table(:form_fields) do
      add :order_id, :integer
    end
  end
end
