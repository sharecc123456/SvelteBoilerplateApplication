defmodule BoilerPlate.Repo.Migrations.CreateIacDocument do
  use Ecto.Migration

  def up do
    create table(:iac_document) do
      add :document_type, :integer
      add :document_id, :integer
      add :file_name, :string
      add :master_form_id, :integer
      add :status, :integer
      add :flags, :integer

      timestamps()
    end
  end

  def down do
    drop table(:iac_document)
  end
end
