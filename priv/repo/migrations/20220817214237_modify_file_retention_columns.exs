defmodule BoilerPlate.Repo.Migrations.ModifyFileRetentionColumns do
  use Ecto.Migration

  def change do
    alter table(:companies) do
      modify :file_retention_period, :integer, default: -1
    end

    alter table(:documents_requests) do
      modify :file_retention_period, :integer, default: nil
    end

    alter table(:raw_documents) do
      modify :file_retention_period, :integer, default: nil
    end

    alter table(:packages) do
      add :file_retention_period, :integer, default: nil
    end

    alter table(:recipients) do
      add :file_retention_period, :integer, default: nil
    end
  end
end
