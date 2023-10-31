defmodule BoilerPlate.Repo.Migrations.AddForm do
  use Ecto.Migration
  def change do
    create table(:forms) do
      add :title, :string
      add :description, :string, default: "-"
      add :status, :integer, default: 0
      add :package_id, :integer

      timestamps()
    end

    create index(:forms, [:package_id])

    create table(:form_fields) do
      add :title, :string
      add :label, :string, default: ""
      add :description, :string, default: "-"
      add :type, :string
      add :required, :boolean
      add :options, {:array, :string}, default: []
      add :form_id, :integer
      add :is_numeric, :boolean, default: false
      add :is_multiple, :boolean, default: false
      add :status, :integer, default: 0

      timestamps()
    end

    create index(:form_fields, [:form_id])

    create table(:form_submissions) do
      add :form_values, :map, default: %{} # this will contain data for form fields
      add :contents_id, :integer
      add :form_id, :integer
      add :return_comments, :string, default: ""
      add :status, :integer, default: 0

      timestamps()
    end

    create index(:form_submissions, [:contents_id])

    alter table(:package_contents) do
      add :forms, {:array, :integer}, default: []
    end
  end
end
