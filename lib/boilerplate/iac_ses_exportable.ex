defmodule BoilerPlate.IACSESExportable do
  use Ecto.Schema
  import Ecto.Changeset

  schema "iac_ses_exportables" do
    field :contents_id, :id
    field :checklist_id, :id
    field :target_checklist_id, :id
    field :iac_document_id, :id
    field :raw_document_id, :id
    field :version, :integer, default: 0
    field :status, :integer, default: 0
    field :flags, :integer, default: 0

    timestamps()
  end

  @doc false
  def changeset(ise, attrs) do
    ise
    |> cast(attrs, [
      :contents_id,
      :checklist_id,
      :target_checklist_id,
      :iac_document_id,
      :raw_document_id,
      :version,
      :status,
      :flags
    ])
    |> validate_required([
      :target_checklist_id,
      :iac_document_id,
      :raw_document_id,
      :version,
      :status,
      :flags
    ])
  end
end
