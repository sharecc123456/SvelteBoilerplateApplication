defmodule BoilerPlate.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :name, :string
      add :access_code, :string
      add :email, :string
      add :admin_of, references(:companies, on_delete: :nothing)
      add :company_id, references(:companies, on_delete: :nothing)
      add :current_package, :integer

      timestamps()
    end

    create index(:users, [:id])
  end
end
