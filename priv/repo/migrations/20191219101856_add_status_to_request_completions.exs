defmodule BoilerPlate.Repo.Migrations.AddStatusToRequestCompletions do
  use Ecto.Migration

  def change do
    alter table(:request_completions) do
      add :status, :integer
    end
  end
end
