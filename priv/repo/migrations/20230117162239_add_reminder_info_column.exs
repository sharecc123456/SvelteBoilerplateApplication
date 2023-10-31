defmodule BoilerPlate.Repo.Migrations.AddReminderInfoColumn do
  use Ecto.Migration

  def change do
    alter table(:package_assignments) do
      add :reminder_state, :map, default: %{last_send_at: nil, total_count: 0, send_by: nil}
    end
  end
end
