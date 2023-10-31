defmodule BoilerPlate.Repo.Migrations.AddRecipientDescPackageContents do
  use Ecto.Migration

  def change do
    alter table(:package_contents) do
      add :recipient_description, :string
    end
  end
end

