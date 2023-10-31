defmodule BoilerPlate.Repo.Migrations.AddExpritationInfo do
  use Ecto.Migration

  def change do
    alter table(:documents_requests) do
      add :expiration_info, :map, default: %{}
      add :enable_expiration_tracking, :boolean, default: false
    end
  end
end
