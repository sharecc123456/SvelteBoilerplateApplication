defmodule BoilerPlate.Repo.Migrations.AddFileConfirmationColumn do
  use Ecto.Migration

  def change do
    alter table(:documents_requests) do
      add :is_confirmation_required, :boolean, default: false
    end
  end
end
