defmodule BoilerPlate.AdhocLink do
  use Ecto.Schema
  import Ecto.Changeset

  schema "adhoc_links" do
    field :adhoc_string, :string
    field :flags, :integer
    field :status, :integer
    field :type, :integer
    field :type_id, :integer
    field :requestor_id, :integer

    timestamps()
  end

  @doc false
  def changeset(adhoc_link, attrs) do
    adhoc_link
    |> cast(attrs, [:type, :type_id, :adhoc_string, :status, :flags, :requestor_id])
    |> validate_required([:type, :type_id, :adhoc_string, :status, :flags, :requestor_id])
  end

  def generate_string() do
    alphabet = Enum.to_list(?a..?z) ++ Enum.to_list(?0..?9)

    for _ <- 1..24, into: "", do: <<Enum.random(alphabet)>>
  end

  def status_to_atom(status) do
    case status do
      0 -> :valid
      1 -> :revoked
      2 -> :deleted
      _ -> :unknown
    end
  end

  def type_to_atom(type) do
    case type do
      1 -> :package
      _ -> :unknown
    end
  end

  def atom_to_type(atom) do
    case atom do
      :package -> 1
      _ -> :unknown
    end
  end
end
