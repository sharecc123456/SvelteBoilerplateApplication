defmodule Boilerplate.Repo.Migrations.CreateCompanyIntegrations do
  use Ecto.Migration

  def change do
    create table(:company_integrations) do
      add :type, :string
      add :data, :map
      add :status, :integer
      add :flags, :integer
      add :company_id, references(:companies, on_delete: :nothing)

      timestamps()
    end

    create index(:company_integrations, [:company_id])
  end
end
