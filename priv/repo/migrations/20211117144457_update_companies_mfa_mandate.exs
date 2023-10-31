defmodule BoilerPlate.Repo.Migrations.UpdateCompaniesMfaMandate do
  use Ecto.Migration

  def change do
    alter table(:companies) do
      add :mfa_mandate, :boolean, default: false
    end
  end
end
