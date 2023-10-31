defmodule BoilerPlate.Repo.Migrations.AddWhitelabeling do
  use Ecto.Migration

  def change do
    alter table(:companies) do
      add :whitelabel_image_name, :string, default: ""
      add :whitelabel_enabled, :boolean, default: false
    end
  end
end
