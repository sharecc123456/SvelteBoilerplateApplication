defmodule BoilerPlate.Repo.Migrations.AddExtraFileUploadFlag do
  use Ecto.Migration

  def change do
    alter table(:documents_requests) do
      add :flags, :integer, default: 0
    end
  end
end
