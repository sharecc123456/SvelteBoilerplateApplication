defmodule BoilerPlate.DocumentTag do
  use Ecto.Schema
  import Ecto.Changeset

  schema "document_tag" do
    field :company_id, :integer, default: nil
    field :name, :string
    field :color, :string
    field :status, :integer, default: 0
    # 0 -> senstive tag
    # 1 -> general
    field :sensitive_level, :integer, default: 1

    timestamps()
  end

  @doc false
  def changeset(document_tag, attrs) do
    document_tag
    |> cast(attrs, [:company_id, :name, :color, :status, :sensitive_level])
    |> validate_required([:company_id, :name, :status])
  end
end
