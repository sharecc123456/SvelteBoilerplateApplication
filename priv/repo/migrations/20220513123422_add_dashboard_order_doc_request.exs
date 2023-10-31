defmodule BoilerPlate.Repo.Migrations.AddDashboardOrderDocRequest do
  use Ecto.Migration

  def change do
    alter table(:documents_requests) do
      add :dashboard_order, :integer, default: 0
    end
  end
end
