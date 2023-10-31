defmodule BoilerPlate.Repo.Migrations.AddSavedSignatureForRequestors do
  use Ecto.Migration

  def change do
    alter table(:requestors) do
      add :esign_consented, :boolean, default: false
      add :esign_consent_date, :utc_datetime
      add :esign_consent_remote_ip, :string
      add :esign_saved_signature, :text
    end
  end
end
