defmodule BoilerPlate.Document do
  use Ecto.Schema
  use Arc.Definition
  import Ecto.Changeset

  schema "documents" do
    field :company_id, :integer
    field :filename, :string
    field :raw_document_id, :integer
    field :recipient_id, :integer
    field :status, :integer
    field :return_comments, :string
    field :assignment_id, :integer
    # bit 1 (2) -> downloaded after completion?
    # bit 2 (4) -> manually uploaded?
    field :flags, :integer

    timestamps()
  end

  @doc false
  def changeset(document, attrs) do
    document
    |> cast(attrs, [
      :raw_document_id,
      :company_id,
      :filename,
      :recipient_id,
      :status,
      :return_comments,
      :assignment_id,
      :flags
    ])
    |> validate_required([
      :raw_document_id,
      :company_id,
      :filename,
      :recipient_id,
      :status,
      :assignment_id
    ])
  end

  def status?(doc) do
    cond do
      doc.status == 1 -> :uploaded
      doc.status == 2 -> :approved
      doc.status == 3 -> :returned
      doc.status == 4 -> :superseded
      doc.status == 5 -> :missing
      doc.status == 6 -> :missing_approved
      doc.status == 7 -> :missing_returned
    end
  end

  # Arc
  @versions [:original]
  # @acl :public_read

  def bucket do
    Application.get_env(:boilerplate, :s3_bucket)
  end

  def validate({file, _}) do
    ~w(.pdf .doc .docx .dotx .xls .xlsx .png .gif .jpg .jpeg .hevc .heic .heif .qbx .qba .qby .qbj .tif .tiff)
    |> Enum.member?(String.downcase(Path.extname(file.file_name)))
  end
end
