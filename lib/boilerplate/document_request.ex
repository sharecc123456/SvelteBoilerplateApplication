alias BoilerPlate.Repo

defmodule BoilerPlate.DocumentRequest do
  use Ecto.Schema
  import Ecto.Changeset

  @type id :: integer()

  schema "documents_requests" do
    field :packageid, :integer
    field :title, :string
    field :status, :integer
    field :description, :string
    field :attributes, {:array, :integer}
    # flags: bit 4 -> Allow Additional file uploads
    # flags: bit 2 -> Recipient manually submitted request
    # flags: bit 6 -> Recipient upload confirmation file request for task request
    # flags: bit 8 -> Recipient upload multiple files for same request
    field :flags, :integer, default: 0
    field :file_retention_period, :integer, default: nil
    field :link, :map, default: %{}

    # set flag to identify if the task has confirmation file uploads
    field :has_file_uploads, :boolean, default: false

    field :dashboard_order, :integer, default: 0

    # set flag to identify if the req needs expiration tracking
    field :enable_expiration_tracking, :boolean, default: false
    field :expiration_info, :map, default: %{}
    field :is_confirmation_required, :boolean, default: false

    timestamps()
  end

  @doc false
  def changeset(document_request, attrs) do
    document_request
    |> cast(attrs, [
      :title,
      :packageid,
      :status,
      :description,
      :attributes,
      :flags,
      :link,
      :has_file_uploads,
      :dashboard_order,
      :file_retention_period,
      :enable_expiration_tracking,
      :expiration_info,
      :is_confirmation_required
    ])
    |> validate_required([:title, :packageid, :status, :attributes])
  end

  def status_to_atom(status) do
    case status do
      0 -> :valid
      1 -> :deleted
      _ -> :unknown
    end
  end

  def attr?(req, a) do
    aid = BoilerPlate.Attribute.atom_to_id(a)

    aid in req.attributes
  end

  def validateFileTypeViewable?(file_name) do
    ~w(.pdf .png .gif .jpg .jpeg .hevc .heic .heif)
    |> Enum.member?(String.downcase(Path.extname(file_name)))
  end

  def get_button_style(),
    do:
      "font-family: 'Nunito', sans-serif; box-sizing: border-box; font-size: 14px; color: #FFF; text-decoration: none; line-height: 2em; font-weight: bold; text-align: center; cursor: pointer; display: inline-block; border-radius: 5px; text-transform: capitalize; background-color: #348eda; margin: 0; border-color: #348eda; border-style: solid; border-width: 10px 80px;"

  def make_a_href_element(link, tagName, style) do
    "<div><a href=#{link} itemprop='url' style='#{style}' target='_blank'>#{tagName}</a></div>"
  end

  def get_changeset_task_description(uploaded_doc, parent_req_id) do
    # create link
    link =
      "#submission/view/2/#{uploaded_doc.assignment_id}/#{uploaded_doc.id}?filePreview=true&newTab=true"

    # create button tag
    # Note: if dynamic links/styling required, send the button element to frontend
    button_element = make_a_href_element(link, "View Confirmation File", "")

    # update task info by appending button element to the description
    req_info = Repo.get(BoilerPlate.DocumentRequest, parent_req_id)
    description = req_info.description || ""
    updated_description = "#{description} #{button_element}"

    changeset(req_info, %{description: updated_description})
  end
end
