defmodule Boilerplate.Repo.Migrations.CreateWebhooks do
  use Ecto.Migration

  def change do
    create table(:webhooks) do
      add :name, :string
      add :events, {:array, :string}
      add :shared_secret, :string
      add :url, :string
      add :status, :integer
      add :flags, :integer
      add :company_id, references(:companies, on_delete: :nothing)

      timestamps()
    end

    create index(:webhooks, [:company_id])
  end
end
