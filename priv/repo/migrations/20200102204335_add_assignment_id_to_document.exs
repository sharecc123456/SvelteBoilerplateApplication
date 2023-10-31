defmodule BoilerPlate.Repo.Migrations.AddAssignmentIdToDocument do
  use Ecto.Migration

  def change do
    alter table(:documents) do
      add :assignment_id, :integer, default: nil
    end
    alter table(:request_completions) do
      add :assignment_id, :integer, default: nil
    end
  end
end
