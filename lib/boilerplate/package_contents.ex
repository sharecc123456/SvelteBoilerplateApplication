alias BoilerPlate.DocumentRequest
alias BoilerPlateWeb.FormController
alias BoilerPlate.Repo

defmodule BoilerPlate.PackageContents do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "package_contents" do
    field :documents, {:array, :integer}
    field :package_id, :integer
    field :requests, {:array, :integer}
    field :forms, {:array, :integer}
    field :status, :integer
    field :title, :string
    field :description, :string
    field :recipient_id, :integer
    field :recipient_description, :string
    field :req_checklist_identifier, :string
    field :enforce_due_date, :boolean, default: false
    field :allow_duplicate_submission, :boolean, default: false
    field :due_days, :integer, default: nil
    field :tags, {:array, :integer}

    timestamps()
  end

  @doc false
  def changeset(package_contents, attrs) do
    package_contents
    |> cast(attrs, [
      :package_id,
      :status,
      :documents,
      :requests,
      :forms,
      :title,
      :description,
      :recipient_id,
      :recipient_description,
      :req_checklist_identifier,
      :enforce_due_date,
      :due_days,
      :allow_duplicate_submission,
      :tags
    ])
    |> validate_required([:package_id, :status, :documents, :requests, :title, :recipient_id])
  end

  defp create_document_request_from_package(pkg) do
    old_requests =
      Repo.all(
        from r in DocumentRequest, where: r.packageid == ^pkg.id and r.status == 0, select: r
      )

    for i <- old_requests do
      flags =
        if i.flags == 2 do
          4
        else
          i.flags
        end

      n =
        Repo.insert!(%DocumentRequest{
          packageid: 0,
          title: i.title,
          status: i.status,
          attributes: i.attributes,
          description: i.description,
          flags: flags,
          link: i.link,
          dashboard_order: i.dashboard_order,
          enable_expiration_tracking: i.enable_expiration_tracking,
          is_confirmation_required: i.is_confirmation_required
        })

      n.id
    end
  end

  def from_package(recipient, pkg) do
    new_requests = create_document_request_from_package(pkg)

    pc = %BoilerPlate.PackageContents{
      documents: pkg.templates,
      package_id: pkg.id,
      requests: new_requests,
      status: 0,
      title: pkg.title,
      description: pkg.description,
      recipient_id: recipient.id,
      allow_duplicate_submission: pkg.allow_duplicate_submission,
      forms: FormController.get_company_form_ids_for_contents(pkg.id),
      tags: pkg.tags
    }

    new_pc = Repo.insert!(pc)

    BoilerPlateWeb.IACController.copy_ses_exportable_to_contents(new_pc.id, pkg.id)

    new_pc
  end

  def get_if_exists(recipient, pkg) do
    pre_pc =
      Repo.all(
        from r in BoilerPlate.PackageContents,
          where:
            r.status == 2 and
              r.recipient_id == ^recipient.id and
              r.package_id == ^pkg.id,
          order_by: [desc: r.inserted_at],
          limit: 1,
          select: r
      )

    if length(pre_pc) != 0 do
      pre_pc |> Enum.at(0)
    else
      nil
    end
  end

  def inprogress_package(recipient, pkg) do
    # Check if there is already an in_progress contents for this pkg
    # If yes, return that, otherwise create a new one.
    pre_pc =
      Repo.all(
        from r in BoilerPlate.PackageContents,
          where:
            r.status == 2 and
              r.recipient_id == ^recipient.id and
              r.package_id == ^pkg.id,
          order_by: [desc: r.inserted_at],
          limit: 1,
          select: r
      )

    if length(pre_pc) != 0 do
      pre_pc |> Enum.at(0)
    else
      create_package_contents(recipient, pkg)
      |> elem(1)
    end
  end

  def create_package_contents(recipient, pkg) do
    old_requests =
      Repo.all(
        from r in DocumentRequest, where: r.packageid == ^pkg.id and r.status == 0, select: r
      )

    new_requests =
      for i <- old_requests do
        flags =
          if i.flags == 2 do
            4
          else
            i.flags
          end

        n =
          Repo.insert!(%DocumentRequest{
            packageid: 0,
            title: i.title,
            status: i.status,
            attributes: i.attributes,
            description: i.description,
            flags: flags,
            link: i.link,
            dashboard_order: i.dashboard_order,
            enable_expiration_tracking: i.enable_expiration_tracking,
            is_confirmation_required: i.is_confirmation_required
          })

        n.id
      end

    pc = %BoilerPlate.PackageContents{
      documents: pkg.templates,
      package_id: pkg.id,
      requests: new_requests,
      status: atom_to_status(:in_progress),
      title: pkg.title,
      description: pkg.description,
      recipient_id: recipient.id,
      forms: FormController.get_company_form_ids_for_contents(pkg.id),
      enforce_due_date: pkg.enforce_due_date,
      allow_duplicate_submission: pkg.allow_duplicate_submission,
      due_days: pkg.due_days,
      tags: pkg.tags
    }

    interim = Repo.insert(pc)

    case interim do
      {:ok, new_pc} ->
        BoilerPlateWeb.IACController.copy_ses_exportable_to_contents(new_pc.id, pkg.id)

      _ ->
        interim
    end

    interim
  end

  def duplicate_package_contents(recipient, contents) do
    old_requests =
      Repo.all(
        from r in DocumentRequest,
          # filter out task confirmations(8), multiple uploads(6) and extra file submission(2)
          where: r.id in ^contents.requests and r.status == 0 and r.flags not in [8, 6, 2],
          select: r
      )

    # flags -> 6 and 8 are client uploaded files

    new_requests =
      for i <- old_requests do
        flags =
          if i.flags == 2 do
            4
          else
            i.flags
          end

        desc =
          if i.has_file_uploads == true do
            ""
          else
            i.description
          end

        n =
          Repo.insert!(%DocumentRequest{
            packageid: 0,
            title: i.title,
            status: i.status,
            attributes: i.attributes,
            description: desc,
            flags: flags,
            link: i.link,
            dashboard_order: i.dashboard_order,
            enable_expiration_tracking: i.enable_expiration_tracking,
            is_confirmation_required: i.is_confirmation_required
          })

        n.id
      end

    pc = %BoilerPlate.PackageContents{
      documents: contents.documents,
      package_id: contents.package_id,
      requests: new_requests,
      status: 0,
      title: contents.title,
      description: contents.description,
      recipient_id: recipient.id,
      forms: FormController.get_company_form_ids_for_contents(contents.package_id),
      enforce_due_date: contents.enforce_due_date,
      due_days: contents.due_days,
      # specific to repeat submission
      allow_duplicate_submission: false,
      tags: contents.tags
    }

    interim = Repo.insert(pc)

    case interim do
      {:ok, new_pc} ->
        BoilerPlateWeb.IACController.copy_ses_exportable_to_contents(
          new_pc.id,
          contents.package_id
        )

      _ ->
        interim
    end

    interim
  end

  def status_to_atom(status) do
    case status do
      0 -> :valid
      1 -> :invalid
      2 -> :in_progress
      _ -> :unknown
    end
  end

  def atom_to_status(atom) do
    case atom do
      :valid -> 0
      :invalid -> 1
      :in_progress -> 2
      _ -> 99
    end
  end
end
