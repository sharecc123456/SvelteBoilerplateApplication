defmodule BoilerPlate.Repo.Migrations.AddFlagsToDocument do
  use Ecto.Migration

  def change do
    alter table(:documents) do
      add :flags, :integer
    end

    alter table(:request_completions) do
      add :flags, :integer
    end
  end
end
