defmodule BoilerPlate.Repo.Migrations.TwoFactorAuth do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :two_factor_state, :integer, default: 0
    end

    create table(:two_factor_computers) do
      add :ip_hash, :string
      add :user_id, :integer
      add :expires, :date

      timestamps()
    end

    create index(:two_factor_computers, [:id])
  end
end
