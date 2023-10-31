defmodule BoilerPlate.Repo.Migrations.CreateRecipients do
  use Ecto.Migration

  def change do
    create table(:recipients) do
      add :organization, :string
      add :user_id, :integer
      add :company_id, :integer
      add :terms_accepted, :boolean, default: false, null: false
      add :status, :integer
      add :name, :string

      timestamps()
    end

  end
end
