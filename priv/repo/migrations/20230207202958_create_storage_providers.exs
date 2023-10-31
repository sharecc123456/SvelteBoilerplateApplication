defmodule BoilerPlate.Repo.Migrations.CreateStorageProviders do
  use Ecto.Migration

  def change do
    create table(:storage_providers) do
      add :backend, :string, default: "s3"
      add :meta_data, :map, default: %{}
      add :status, :integer, default: 0
      add :flags, :integer, default: 0

      timestamps()
    end

    alter table(:companies) do
      add :temporary_storage_provider, references(:storage_providers, on_delete: :nothing)
      add :permanent_storage_provider, references(:storage_providers, on_delete: :nothing)
    end

    create index(:companies, [:temporary_storage_provider])
    create index(:companies, [:permanent_storage_provider])
  end
end
