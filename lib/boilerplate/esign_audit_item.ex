defmodule BoilerPlate.EsignAuditItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "esign_audit_log" do
    field :creator_type, :integer
    field :item_data, :string
    field :item_type, :integer
    # field :company_id, :id

    # Used when item_type == :opened_document || :submitted_document
    field :iaf_id, :id

    # Used when item_type == :signature
    field :field_id, :id

    field :requestor_id, :id
    field :recipient_id, :id
    field :ip_address, :string
    field :status, :integer
    field :flags, :integer

    timestamps()
  end

  @doc false
  def changeset(esign_audit_item, attrs) do
    esign_audit_item
    |> cast(attrs, [:creator_type, :item_type, :item_data, :ip_address])
    |> validate_required([:creator_type, :item_type, :item_data, :ip_address])
  end

  def creator_type_to_atom(1), do: :requestor
  def creator_type_to_atom(2), do: :recipient
  def creator_type_to_atom(_), do: :unknown
  def atom_to_creator_type(:requestor), do: 1
  def atom_to_creator_type(:recipient), do: 2
  def atom_to_creator_type(_), do: 0

  def item_type_to_atom(1), do: :field_fill
  def item_type_to_atom(2), do: :signature
  def item_type_to_atom(3), do: :opened_document
  def item_type_to_atom(4), do: :submitted_document
  def item_type_to_atom(_), do: :unknown
  def atom_to_item_type(:field_fill), do: 1
  def atom_to_item_type(:signature), do: 2
  def atom_to_item_type(:opened_document), do: 3
  def atom_to_item_type(:submitted_document), do: 4
  def atom_to_item_type(_), do: 0
end
