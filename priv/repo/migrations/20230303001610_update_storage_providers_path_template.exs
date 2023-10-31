defmodule BoilerPlate.Repo.Migrations.UpdateStorageProvidersPathTemplate do
  use Ecto.Migration

  def change do
    alter table(:storage_providers) do
      add(:path_template, :string, default: "/Boilerplate Uploads")
      add(:auto_export, :boolean, default: true)
    end
  end
end
