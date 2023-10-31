defmodule BoilerPlate.Repo.Migrations.AddRecipientContentsToIacDocument do
  use Ecto.Migration

  def change do
    alter table(:iac_document) do
      add :contents_id, :integer, default: 0
      add :recipient_id, :integer, default: 0
      add :raw_document_id, :integer, default: 0
    end
  end
end
