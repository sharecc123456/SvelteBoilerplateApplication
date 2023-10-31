defmodule BoilerPlate.Repo.Migrations.AddSavedSignature do
  use Ecto.Migration

  def change do
    alter table(:recipients) do
      add :esign_saved_signature, :text
    end
  end
end
