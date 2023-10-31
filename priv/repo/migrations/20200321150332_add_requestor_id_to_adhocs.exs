defmodule BoilerPlate.Repo.Migrations.AddRequestorIdToAdhocs do
  use Ecto.Migration

  def change do
    alter table(:adhoc_links) do
      add :requestor_id, :integer
    end
  end
end
