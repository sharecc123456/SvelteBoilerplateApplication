defmodule BoilerPlate.Repo.Migrations.AddNotificationTable do
  use Ecto.Migration

  def change do
    create table(:notification) do
      add :title, :string, default: ""
      add :type, :string
      add :message, :string
      add :document_type, :string
      add :document_id, :integer
      add :assignment_id, :integer
      add :company_id, :integer
      add :user_id, :integer
      add :flags, :integer, default: 0
      add :status, :integer, default: 0

      timestamps()
    end
  end
end
