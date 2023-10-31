defmodule BoilerPlate.Repo.Migrations.CreatePackages do
  use Ecto.Migration

  def change do
    create table(:packages) do
      add :title, :string
      add :description, :string
      add :templates, {:array, :integer}
      add :company_id, references(:companies, on_delete: :nothing)

      timestamps()
    end

    create index(:packages, [:company_id])
  end
end
