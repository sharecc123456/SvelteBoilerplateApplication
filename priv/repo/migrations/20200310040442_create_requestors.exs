defmodule BoilerPlate.Repo.Migrations.CreateRequestors do
  use Ecto.Migration

  def change do
    create table(:requestors) do
      add :user_id, :integer
      add :company_id, :integer
      add :terms_accepted, :boolean, default: false, null: false
      add :status, :integer
      add :name, :string
      add :organization, :string

      timestamps()
    end

  end
end
