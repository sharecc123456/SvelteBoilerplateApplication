defmodule Boilerplate.Repo.Migrations.CreateUserSso do
  use Ecto.Migration

  def change do
    create table(:user_sso) do
      add :type, :string
      add :data, :map
      add :status, :integer
      add :flags, :integer
      add :user_id, references(:users, on_delete: :nothing)

      timestamps()
    end

    create index(:user_sso, [:user_id])
  end
end
