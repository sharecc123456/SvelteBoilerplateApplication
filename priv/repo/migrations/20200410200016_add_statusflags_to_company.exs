defmodule BoilerPlate.Repo.Migrations.AddStatusflagsToCompany do
  use Ecto.Migration

  def up do
    alter table(:companies) do
      add :status, :integer
      add :flags, :integer
    end

    flush()

    BoilerPlate.Repo.update_all(BoilerPlate.Company, set: [status: 0, flags: 0])
  end

  def down do
    alter table(:companies) do
      remove :status
      remove :flags
    end
  end
end
