defmodule BoilerPlate.Repo.Migrations.AddMasterIdInForm do
  use Ecto.Migration

  def change do
    alter table("forms") do
      add :master_form_id, :integer, default: nil
    end
  end
end
