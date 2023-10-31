defmodule BoilerPlate.Attribute do
  use Ecto.Schema
  import Ecto.Changeset

  schema "attributes" do
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(attribute, attrs) do
    attribute
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end

  def atom_to_id(atom) do
    case atom do
      :multiple_file_upload -> 1
      :text_input           -> 2
      _ -> 0
    end
  end
end
