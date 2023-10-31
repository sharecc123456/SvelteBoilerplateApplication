defmodule Boilerplate.Repo.Migrations.CreateIacLabel do
  use Ecto.Migration

  def change do
    create table(:iac_label) do
      add :value, :string
      add :status, :integer
      add :flags, :integer
      add :company_id, references(:companies, on_delete: :nothing)
      add :inserted_by, references(:users, on_delete: :nothing)

      timestamps()
    end

    create index(:iac_label, [:company_id])
    create index(:iac_label, [:inserted_by])
  end
end
