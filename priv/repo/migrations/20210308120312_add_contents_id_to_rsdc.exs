defmodule BoilerPlate.Repo.Migrations.AddContentsIdToRsdc do
  use Ecto.Migration

  def change do
    alter table(:raw_documents_customized) do
      add :contents_id, :integer, default: 0
    end
  end
end
