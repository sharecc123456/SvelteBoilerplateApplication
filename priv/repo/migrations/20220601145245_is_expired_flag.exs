defmodule BoilerPlate.Repo.Migrations.IsExpiredFlag do
  use Ecto.Migration

  def change do
    alter table(:request_completions) do
      add :is_expired, :boolean, default: false
    end
  end
end
