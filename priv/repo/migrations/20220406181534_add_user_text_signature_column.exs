defmodule BoilerPlate.Repo.Migrations.AddUserTextSignatureColumn do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :text_signature, :string, default: ""
    end
  end
end
