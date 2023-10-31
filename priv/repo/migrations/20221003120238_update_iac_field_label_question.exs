defmodule BoilerPlate.Repo.Migrations.UpdateIacFieldLabelQuestion do
  use Ecto.Migration

  def change do
    alter table(:iac_field) do
      add :label_question, :string, default: nil
      add :label_question_type, :string, default: nil
      add :label_id, references(:iac_label, on_delete: :nothing)
    end

    create index(:iac_field, [:label_id])

    alter table(:iac_label) do
      add :question, :string, default: nil
    end
  end
end
