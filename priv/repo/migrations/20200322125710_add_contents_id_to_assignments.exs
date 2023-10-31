defmodule BoilerPlate.Repo.Migrations.AddContentsIdToAssignments do
  use Ecto.Migration

  def change do
    alter table(:package_assignments) do
      add :contents_id, :integer
    end
    alter table(:packages) do
      add :status, :integer
    end
    alter table(:documents_requests) do
      add :status, :integer
    end
    alter table(:package_contents) do
      add :title, :string
      add :description, :string
    end
  end
end
