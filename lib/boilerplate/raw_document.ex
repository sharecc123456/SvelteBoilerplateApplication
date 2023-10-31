import Bitwise

defmodule BoilerPlate.RawDocument do
  use Ecto.Schema
  alias BoilerPlate.Repo
  import Ecto.Changeset
  import Ecto.Query
  use Arc.Definition

  @type id :: integer

  schema "raw_documents" do
    field :description, :string
    field :file_name, :string
    field :name, :string
    field :company_id, :id
    # bit 1 -> incompatible for IACS
    field :type, :integer
    field :flags, :integer
    field :iac_master_id, :integer
    field :editable_during_review, :boolean, default: false
    field :is_archived, :boolean, default: false
    field :file_retention_period, :integer, default: nil
    field :tags, {:array, :integer}
    field :version, :integer, default: 0

    timestamps()
  end

  @doc false
  def changeset(raw_document, attrs) do
    raw_document
    |> cast(attrs, [
      :name,
      :description,
      :file_name,
      :company_id,
      :type,
      :flags,
      :iac_master_id,
      :editable_during_review,
      :is_archived,
      :file_retention_period,
      :tags,
      :version
    ])
    |> validate_required([:name, :file_name, :type, :flags])
  end

  def iac_setup?(rd) do
    rd.iac_master_id != nil and rd.iac_master_id != 0
  end

  def is_template_archived?(rd) do
    rd.is_archived == true
  end

  def is_ok_for_iac?(rd) do
    String.ends_with?(rd.file_name, ".pdf")
  end

  def is_hidden?(rd) do
    if rd == nil do
      false
    else
      (rd.flags &&& 1) == 1 or (rd.flags &&& 4) == 4
    end
  end

  # Recipient Specific
  def is_rspec?(rd) do
    if rd == nil do
      false
    else
      (rd.flags &&& 2) == 2
    end
  end

  # Info Specific
  def is_info?(rd) do
    if rd == nil do
      false
    else
      (rd.flags &&& 8) == 8
    end
  end

  def is_contents_specific?(rd) do
    if rd == nil do
      false
    else
      (rd.flags &&& 4) == 4
    end
  end

  @storage_mod Application.compile_env(:boilerplate, :storage_backend, StorageAwsImpl)

  def hash_document(rd) do
    bucket = Application.get_env(:boilerplate, :s3_bucket)

    body = @storage_mod.download_file_stream(bucket, "uploads/documents/#{rd.file_name}")

    :crypto.hash(:sha3_256, body) |> Base.encode16() |> String.downcase()
  end

  # Return all raw documents that are associated with
  # the company passed in the argument
  def all_associated_with(company) do
    cid = company.id

    Repo.all(
      from u in BoilerPlate.RawDocument,
        order_by: u.inserted_at,
        where: u.company_id == ^cid,
        select: u
    )
    |> Enum.filter(&(!BoilerPlate.RawDocument.is_hidden?(&1)))
  end

  def get_company_documents_count_by_period(
        :generic,
        company_id,
        start_time_period,
        end_time_period
      ) do
    query =
      from doc in BoilerPlate.RawDocument,
        # count repeat submission packages
        where:
          doc.flags != 2 and doc.company_id == ^company_id and
            doc.inserted_at >= ^start_time_period and doc.inserted_at <= ^end_time_period,
        select: doc

    Repo.aggregate(query, :count, :id)
  end

  def get_company_documents_count_by_period(
        :rspec,
        company_id,
        start_time_period,
        end_time_period
      ) do
    query =
      from doc in BoilerPlate.RawDocument,
        # count repeat submission packages
        where:
          doc.flags == 2 and doc.company_id == ^company_id and
            doc.inserted_at >= ^start_time_period and doc.inserted_at <= ^end_time_period,
        select: doc

    Repo.aggregate(query, :count, :id)
  end

  @non_iac_file_types [".xlsx", ".xls"]
  def file_extension_type(ext) do
    cond do
      ext in @non_iac_file_types -> 1
      True -> 0
    end
  end

  # Arc

  @versions [:original]
  # @acl :public_read

  def bucket do
    Application.get_env(:boilerplate, :s3_bucket)
  end

  # make these filetype as a common type with ability to customize for each model
  def validate({file, _}) do
    ~w(.pdf .doc .docx .dotx .xls .xlsx .png .gif .jpg .jpeg .hevc .heic .heif .csv .txt .qbx .qba .qby .qbj .tif .tiff)
    |> Enum.member?(String.downcase(Path.extname(file.file_name)))
  end
end
