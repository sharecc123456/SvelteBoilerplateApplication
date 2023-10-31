defmodule BoilerPlate.Repo.Migrations.UpdateUsersWithCurrentDoc do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :current_document_index, :integer
    end
  end
end
