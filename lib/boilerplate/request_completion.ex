defmodule BoilerPlate.RequestCompletion do
  use Ecto.Schema
  use Arc.Definition
  import Ecto.Changeset

  schema "request_completions" do
    field :file_name, :string
    field :recipientid, :integer
    field :requestid, :integer
    field :company_id, :integer
    # bit 8 (r) -> request deleted?
    field :status, :integer
    field :return_comments, :string
    field :assignment_id, :integer
    field :is_missing, :boolean
    field :missing_reason, :string
    # bit 1 (2) -> downloaded?
    # bit 2 (r) -> manually uploaded?
    field :flags, :integer
    field :file_request_reference, :integer, default: nil

    # has document uploaded expired?
    field :is_expired, :boolean
    timestamps()
  end

  @doc false
  def changeset(request_completion, attrs) do
    request_completion
    |> cast(attrs, [
      :requestid,
      :recipientid,
      :file_name,
      :company_id,
      :status,
      :return_comments,
      :assignment_id,
      :is_missing,
      :missing_reason,
      :flags,
      :file_request_reference,
      :is_expired
    ])
    |> validate_required([:requestid, :recipientid, :company_id, :status, :assignment_id])
  end

  # Arc
  @versions [:original]
  # @acl :public_read

  def bucket do
    Application.get_env(:boilerplate, :s3_bucket)
  end

  def validate({file, _}) do
    file_ext = String.downcase(Path.extname(file.file_name))
    # Regex tubo tax file matching .tax extensions
    turbo_regex = ~r/.tax/

    ~w(.pdf .doc .docx .dotx .xls .xlsx .png .gif .csv .jpg .jpeg .hevc .heic .heif .qbx .qba .qby .qbj .tif .tiff)
    |> Enum.member?(file_ext) || file_ext =~ turbo_regex
  end

  def status_to_atom(_status) do
  end

  def atom_to_status(_atom) do
  end
end
