defmodule BoilerPlate.Repo.Migrations.AddEditableDuringReview do
  use Ecto.Migration

  def change do
    alter table(:raw_documents) do
      add :editable_during_review, :boolean, default: false
    end
  end
end
