defmodule BoilerPlate.Repo.Migrations.AddPlanToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :plan, :string, default: ""
    end
  end
end
