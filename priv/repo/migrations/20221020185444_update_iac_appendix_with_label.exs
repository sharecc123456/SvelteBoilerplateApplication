defmodule BoilerPlate.Repo.Migrations.UpdateIacAppendixWithLabel do
  use Ecto.Migration

  def change do
    alter table(:iac_appendices) do
      add :appendix_label, :string, default: ""
      add :appendix_reference, :string, default: ""
    end
  end
end
