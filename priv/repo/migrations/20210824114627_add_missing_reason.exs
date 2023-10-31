defmodule BoilerPlate.Repo.Migrations.AddMissingReason do
  use Ecto.Migration

  def change do
    alter table(:request_completions) do
      add :is_missing, :boolean, default: false
      add :missing_reason, :string, default: ""
    end
  end
end
