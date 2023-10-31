defmodule BoilerPlate.Repo.Migrations.AddTaskLinkColumn do
  use Ecto.Migration

  def change do
    alter table(:documents_requests) do
      add :link, :map, default: %{}
    end
  end
end
