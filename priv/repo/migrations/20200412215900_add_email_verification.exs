defmodule BoilerPlate.Repo.Migrations.AddEmailVerification do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :verified, :boolean
      add :verification_code, :string
    end

    flush()

    BoilerPlate.Repo.update_all(BoilerPlate.User, set: [verified: true, verification_code: ""])
  end

  def down do
    alter table(:users) do
      remove :verified
      remove :verification_code
    end

    flush()
  end
end
