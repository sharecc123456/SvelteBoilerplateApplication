defmodule BoilerPlate.Repo.Migrations.AddFileRetentionPeriod do
  use Ecto.Migration

  def change do
    # file_retention_period
    # nil -> not set
    # -1 -> infinite/forever
    # val > 0 -> finite
    alter table(:companies) do
      add :file_retention_period, :integer, default: -1
    end

    alter table(:documents_requests) do
      add :file_retention_period, :integer, default: nil
    end
    
    alter table(:raw_documents) do
      add :file_retention_period, :integer, default: nil
    end
  end
end
