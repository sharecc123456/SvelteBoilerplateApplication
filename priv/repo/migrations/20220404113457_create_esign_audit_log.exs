defmodule Boilerplate.Repo.Migrations.CreateEsignAuditLog do
  use Ecto.Migration

  def change do
    create table(:esign_audit_log) do
      add :creator_type, :integer
      add :item_type, :integer
      add :item_data, :text
      # add :company_id, references(:companies, on_delete: :nothing)
      add :iaf_id, references(:iac_assigned_forms, on_delete: :nothing)
      add :field_id, references(:iac_field, on_delete: :nothing)
      add :requestor_id, references(:requestors, on_delete: :nothing)
      add :recipient_id, references(:recipients, on_delete: :nothing)
      add :ip_address, :string
      add :status, :integer
      add :flags, :integer

      timestamps()
    end

    # create index(:esign_audit_log, [:company_id])
    create index(:esign_audit_log, [:iaf_id])
    create index(:esign_audit_log, [:field_id])
    create index(:esign_audit_log, [:requestor_id])
    create index(:esign_audit_log, [:recipient_id])
  end
end
