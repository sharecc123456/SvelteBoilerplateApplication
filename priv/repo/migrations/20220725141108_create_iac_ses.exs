defmodule BoilerPlate.Repo.Migrations.CreateIacSes do
  use Ecto.Migration

  def change do
    create table(:iac_ses_exportables) do
      # Attached to a contents
      add :contents_id, references(:package_contents, on_delete: :nothing)

      # Attached to a checklist, the checklist that is to be exported
      add :checklist_id, references(:packages, on_delete: :nothing)

      # the internal target checklist which will be used as the base for the contents
      add :target_checklist_id, references(:packages, on_delete: :nothing)

      # the IAC document of the target document
      add :iac_document_id, references(:iac_document, on_delete: :nothing)

      # the raw template that is to be filled
      add :raw_document_id, references(:raw_documents, on_delete: :nothing)

      # IAC/SES internal version number (to support transparent IAC/SES upgrades)
      add :version, :integer, default: 0

      # Misc fields for other upgrades later
      add :status, :integer, default: 0
      add :flags, :integer, default: 0

      timestamps()
    end

    create index(:iac_ses_exportables, [:id])

    create table(:iac_appendices) do
      # the IAC document of the target document
      add :iac_assigned_form_id, references(:iac_assigned_forms, on_delete: :nothing)

      # The form from which this appendix was generated.
      add :form_id, references(:forms, on_delete: :nothing)

      # The file name of the appendix, stored in S3.
      add :appendix_name, :string, default: ""

      # The order of the appendix, 0 first, 1 second, etc.
      add :appendix_order, :integer, default: 0

      # IAC/SES internal version number (to support transparent IAC/SES upgrades)
      add :version, :integer, default: 0

      # Misc fields for other upgrades later
      add :status, :integer, default: 0
      add :flags, :integer, default: 0

      timestamps()
    end
  end
end
