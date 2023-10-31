alias BoilerPlate.RawDocument
alias BoilerPlate.RawDocumentCustomized

defmodule BoilerPlate.IACDocument do
  use Ecto.Schema
  alias BoilerPlate.Repo
  import Ecto.Changeset

  @type id :: integer

  schema "iac_document" do
    field :document_type, :integer
    field :document_id, :integer

    # Used by all
    field :file_name, :string
    field :master_form_id, :integer

    # Used by raw_document_customized only
    field :contents_id, :integer, default: 0
    field :recipient_id, :integer, default: 0
    field :raw_document_id, :integer, default: 0

    # Used by all
    field :status, :integer, default: 0
    field :flags, :integer, default: 0

    timestamps()
  end

  @doc false
  def changeset(iacfd, attrs) do
    iacfd
    |> cast(attrs, [
      :document_type,
      :document_id,
      :contents_id,
      :recipient_id,
      :raw_document_id,
      :file_name,
      :master_form_id,
      :status,
      :flags
    ])
    |> validate_required([
      :document_type,
      :document_id,
      :contents_id,
      :recipient_id,
      :raw_document_id,
      :file_name,
      :master_form_id,
      :status,
      :flags
    ])
  end

  ##
  ## Internal
  ##

  defp specialize_query_for(:raw_document, _), do: %{flags: 0}

  defp specialize_query_for(:raw_document_customized, rsdc) do
    %{
      recipient_id: rsdc.recipient_id,
      contents_id: rsdc.contents_id,
      # raw document customized and iac document flags are same
      flags: rsdc.flags
    }
  end

  ##
  ## Property helpers
  ##

  def document_type(:unknown), do: 0
  def document_type(:raw_document), do: 1
  def document_type(:raw_document_customized), do: 2

  def type_document(0), do: :unknown
  def type_document(1), do: :raw_document
  def type_document(2), do: :raw_document_customized

  def flags_type_to_atom(flag) do
    case flag do
      0 -> :requester
      5 -> :recipient
      _ -> :unknown
    end
  end

  def atom_to_flags_type(atom) do
    case atom do
      :requester -> 0
      :recipient -> 5
      _ -> -1
    end
  end

  def base_document_id(iac_doc) when iac_doc.document_type == 1, do: iac_doc.document_id
  def base_document_id(iac_doc) when iac_doc.document_type == 2, do: iac_doc.raw_document_id

  ##
  ## More complex properties
  ##

  # Check whether the IACDocument is ready to be used
  def setup?(iac_doc) do
    # We are considered ready if we have a master form attached.
    # ... and our status is zero
    iac_doc != nil and
      iac_doc.master_form_id != nil and
      iac_doc.master_form_id != 0 and
      iac_doc.status == 0
  end

  # Check if IAC is setup for a particular document d of class x
  def setup_for?(x, d) do
    d != nil and get_for(x, d) |> setup?()
  end

  # Get the document
  def get_for(x, d) do
    query =
      %{
        document_type: document_type(x),
        document_id: d.id,
        status: 0
      }
      |> Map.merge(specialize_query_for(x, d))

    Repo.get_by(BoilerPlate.IACDocument, query)
  end

  def clone_into(iac_doc, :raw_document_customized, rsdc) do
    new = %BoilerPlate.IACDocument{
      document_type: BoilerPlate.IACDocument.document_type(:raw_document_customized),
      document_id: rsdc.id,
      file_name: iac_doc.file_name,
      master_form_id: iac_doc.master_form_id,
      contents_id: rsdc.contents_id,
      recipient_id: rsdc.recipient_id,
      raw_document_id: rsdc.raw_document_id,
      status: 0,
      # to add recipient created checklist
      flags:
        if Map.has_key?(rsdc, :flags) do
          rsdc.flags
        else
          0
        end
    }

    Repo.insert!(new)
  end

  defp get_rsd_of_rsdc(iac_doc) do
    rsdc = Repo.get(RawDocumentCustomized, iac_doc.document_id)

    Repo.get(RawDocument, rsdc.raw_document_id)
  end

  # Retrieve the company_id from the underlying document
  def company_id_of(iac_doc) do
    case type_document(iac_doc.document_type) do
      :raw_document -> Repo.get(RawDocument, iac_doc.document_id).company_id
      :raw_document_customized -> get_rsd_of_rsdc(iac_doc).company_id
      _ -> raise "unknown document_type #{iac_doc.document_type}"
    end
  end

  # Retrieve the name from the underlying document
  def name_of(iac_doc) do
    case type_document(iac_doc.document_type) do
      :raw_document -> Repo.get(RawDocument, iac_doc.document_id).name
      :raw_document_customized -> get_rsd_of_rsdc(iac_doc).name
      _ -> raise "unknown document_type #{iac_doc.document_type}"
    end
  end

  # Retrieve the description from the underlying document
  def description_of(iac_doc) do
    case type_document(iac_doc.document_type) do
      :raw_document -> Repo.get(RawDocument, iac_doc.document_id).description
      :raw_document_customized -> get_rsd_of_rsdc(iac_doc).description
      _ -> raise "unknown document_type #{iac_doc.document_type}"
    end
  end

  # Generate the back URL for the IACDocument
  def back_url_for(iac_doc) do
    case type_document(iac_doc.document_type) do
      :raw_document ->
        "/document/#{iac_doc.document_id}/edit"

      :raw_document_customized ->
        "/package/#{iac_doc.contents_id}/#{iac_doc.recipient_id}/customize"

      _ ->
        "/iacdoc/#{iac_doc.id}/backcrash"
    end
  end

  # Check if this IACDocument is countersign enabled
  def is_countersign(iac_doc) do
    case type_document(iac_doc.document_type) do
      :raw_document ->
        rd = Repo.get(RawDocument, iac_doc.document_id)
        rd.editable_during_review

      :raw_document_customized ->
        rd = Repo.get(RawDocument, iac_doc.raw_document_id)
        rd.editable_during_review

      :unknown ->
        raise "Invalid IACDocument state for IACDocument #{iac_doc.id}: #{iac_doc.document_type}"
    end
  end
end
