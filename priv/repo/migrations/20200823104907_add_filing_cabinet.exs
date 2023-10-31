defmodule BoilerPlate.Repo.Migrations.AddFilingCabinet do
  use Ecto.Migration

  def up do
    create table(:cabinet) do
      add :name, :string
      add :recipient_id, :integer
      add :requestor_id, :integer
      add :company_id, :integer
      add :filename, :string
      add :status, :integer
      add :flags, :integer

      timestamps()
    end

    flush()
  end

  def down do
    drop table(:cabinet)
  end

end
