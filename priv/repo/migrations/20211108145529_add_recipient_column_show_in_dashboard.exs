defmodule BoilerPlate.Repo.Migrations.AddRecipientColumnShowInDashboard do
  use Ecto.Migration

  def change do
    alter table(:recipients) do
      add :show_in_dashboard, :boolean, default: true
    end
  end
end

