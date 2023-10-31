defmodule BoilerPlate.Repo.Migrations.AddFlagsToRawdocument do
  use Ecto.Migration

  def change do
    alter table(:raw_documents) do
      add :flags, :integer
    end
  end
end
