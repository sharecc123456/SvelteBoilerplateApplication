defmodule BoilerPlate.Repo.Migrations.AddFlagsToUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :flags, :integer
    end
  end
end
