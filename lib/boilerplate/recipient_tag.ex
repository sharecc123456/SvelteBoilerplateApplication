defmodule BoilerPlate.RecipientTag do
  use Ecto.Schema
  import Ecto.Changeset
  alias BoilerPlate.Repo

  schema "recipient_tags" do
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
  def changeset(recipient_tag, attrs) do
    recipient_tag
    |> cast(attrs, [:company_id, :name, :color, :status, :sensitive_level])
    |> validate_required([:company_id, :name, :status])
  end

  def create(attrs) do
    cs = changeset(%__MODULE__{}, attrs)

    if cs.valid? do
      case Repo.insert(cs) do
        {:ok, n} -> {:ok, n}
        {:error, x} -> {:ecto_error, x}
      end
    else
      {:error, :invalid_changeset}
    end
  end
end
