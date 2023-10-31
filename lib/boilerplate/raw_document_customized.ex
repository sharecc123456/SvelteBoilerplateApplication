alias BoilerPlate.Repo

defmodule BoilerPlate.RawDocumentCustomized do
  use Ecto.Schema
  use Arc.Definition
  import Ecto.Changeset
  import Ecto.Query

  @doc_base_version 1

  def get_base_version, do: @doc_base_version

  schema "raw_documents_customized" do
    field :flags, :integer
    # bit 0 -> direct copy of RSD, do NOT delete the file
    # bit 5 -> Recipient created RSD, do NOT delete the file
    field :raw_document_id, :integer
    field :recipient_id, :integer
    field :contents_id, :integer, default: 0
    # status == 1 => stale
    field :status, :integer
    field :file_name, :string

    # document update version track
    field :version, :integer, default: 1

    timestamps()
  end

  @doc false
  def changeset(raw_document_customized, attrs) do
    raw_document_customized
    |> cast(attrs, [:recipient_id, :contents_id, :raw_document_id, :flags, :status, :file_name])
    |> validate_required([
      :recipient_id,
      :contents_id,
      :raw_document_id,
      :flags,
      :status,
      :file_name
    ])
  end

  def get_latest_rdc(rsid, cid, rid) do
    Repo.one(
      from r in BoilerPlate.RawDocumentCustomized,
        where:
          r.contents_id == ^cid and r.recipient_id == ^rid and
            r.raw_document_id == ^rsid,
        order_by: [desc: r.inserted_at],
        limit: 1,
        select: r
    )
  end

  defp get_version_history_rsd_doc(rsid, cid, rid) do
    Repo.all(
      from r in BoilerPlate.RawDocumentCustomized,
        where:
          r.raw_document_id == ^rsid and
            r.contents_id == ^cid and
            r.recipient_id == ^rid,
        order_by: [desc: r.version, desc: r.inserted_at],
        select: %{
          customization_id: r.id,
          inserted_at: r.inserted_at,
          recipient_id: r.recipient_id,
          raw_doc_id: r.raw_document_id,
          version: r.version
        }
    )
  end

  def get_document_history(rsid, cid, rid) do
    versions = get_version_history_rsd_doc(rsid, cid, rid)

    is_document_updated? = not (Enum.all?(versions, &(&1.version == @doc_base_version)))

    if is_document_updated? do
      original_document = Enum.find(versions, fn x -> x.version == @doc_base_version end)

      edit_versions = Enum.filter(versions, &(&1.version != @doc_base_version))
      edit_versions ++ [original_document]
    else
      []
    end

  end

  def get_verison_number_customized_doc(rsid, cid, rid) do
    case get_latest_rdc(rsid, cid, rid) do
      %{version: latest_version} -> latest_version + 1
      nil -> 1
    end
  end

  # Arc
  @versions [:original]
  # @acl :public_read

  def bucket do
    Application.get_env(:boilerplate, :s3_bucket)
  end

  def validate({file, _}) do
    ~w(.pdf .doc .docx .dotx .xls .xlsx .png .gif .jpg .jpeg .hevc .heic .heif .tif .tiff)
    |> Enum.member?(String.downcase(Path.extname(file.file_name)))
  end
end
