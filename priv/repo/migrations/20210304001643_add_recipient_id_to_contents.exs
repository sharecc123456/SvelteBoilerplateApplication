defmodule BoilerPlate.Repo.Migrations.AddRecipientIdToContents do
  use Ecto.Migration

  def change do
    alter table(:package_contents) do
      add :recipient_id, :integer, default: 0
    end
  end
end
