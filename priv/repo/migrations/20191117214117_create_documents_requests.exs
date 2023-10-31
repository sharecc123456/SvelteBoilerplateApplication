defmodule BoilerPlate.Repo.Migrations.CreateDocumentsRequests do
  use Ecto.Migration

  def change do
    create table(:documents_requests) do
      add :title, :string
      add :packageid, :integer

      timestamps()
    end

  end
end
