defmodule BoilerPlate.Repo.Migrations.AddDescriptionToDocumentRequest do
  use Ecto.Migration

  def change do
    alter table(:documents_requests) do
      add :description, :text, default: ""
    end
  end
end
