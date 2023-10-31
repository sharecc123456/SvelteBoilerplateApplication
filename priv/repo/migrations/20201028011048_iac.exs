defmodule BoilerPlate.Repo.Migrations.Iac do
  use Ecto.Migration

  def up do
    create table(:iac_master_forms) do
      add :company_id, :integer
      add :creator_id, :integer
      add :fields, {:array, :integer}
      add :base_pdf, :string
      add :name, :string
      add :description, :string
      add :status, :integer
      add :flags, :integer

      timestamps()
    end

    create table(:iac_assigned_forms) do
      add :company_id, :integer
      add :contents_id, :integer
      add :master_form_id, :integer
      add :recipient_id, :integer
      add :fields, {:array, :integer}
      add :status, :integer
      add :flags, :integer

      timestamps()
    end

    create table(:iac_field) do
      add :parent_id, :integer
      add :parent_type, :integer
      add :name, :string
      add :location_type, :integer
      add :location_value_1, :float
      add :location_value_2, :float
      add :location_value_3, :float
      add :location_value_4, :float
      add :location_value_5, :float
      add :location_value_6, :float
      add :field_type, :integer
      add :master_field_id, :integer
      add :set_value, :string
      add :default_value, :string
      add :internal_value_1, :string
      add :status, :integer
      add :flags, :integer

      timestamps()
    end

    create table(:iac_signatures) do
      add :signature_file, :text
      add :signature_field, :integer
      add :audit_ip, :string
      add :audit_user, :integer
      add :audit_sign_start, :utc_datetime
      add :audit_sign_end, :utc_datetime
      add :status, :integer
      add :flags, :integer

      timestamps()
    end

    create table(:iac_signature_hashes) do
      add :signature_hash, :string
      add :signature_id, :integer
      add :audit_ip, :string
      add :audit_user, :integer
      add :audit_sign_start, :utc_datetime
      add :audit_sign_end, :utc_datetime
      add :status, :integer
      add :flags, :integer

      timestamps()
    end

    flush()

    alter table(:raw_documents) do
      add :iac_master_id, :integer
    end

    flush()

    alter table(:recipients) do
      add :esign_consented, :boolean, default: false
      add :esign_consent_date, :utc_datetime
      add :esign_consent_remote_ip, :string
    end
  end

  def down do
    drop table(:iac_master_forms)
    drop table(:iac_assigned_forms)
    drop table(:iac_field)
    drop table(:iac_signatures)

    alter table(:raw_documents) do
      remove :iac_master_id
    end
  end
end
