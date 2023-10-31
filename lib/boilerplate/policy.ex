alias BoilerPlate.Package
alias BoilerPlate.Recipient
alias BoilerPlate.PackageAssignment
alias BoilerPlate.Repo
alias BoilerPlateWeb.ApiController
import Ecto.Query

defmodule BoilerPlate.Policy do
  def can_delete?(:package, _pkg) do
    true
  end

  def can_delete?(:template, doc) do
    query =
      from p in Package,
        where: ^doc.id in p.templates and p.status == 0,
        select: p

    Repo.aggregate(query, :count, :id) == 0
  end

  def can_delete?(:recipient, user) do
    assigns =
      Repo.all(
        from pa in PackageAssignment,
          where: pa.recipient_id == ^user.id and pa.status == 0,
          select: pa
      )

    recipient = Repo.get(Recipient, user.id)
    assignments = ApiController.do_make_assignments_of_requestor(assigns, recipient)

    no_open_assignments =
      assignments
      |> Enum.all?(&(&1.state.status != 0))

    no_open_assignments
  end

  def can_archive?(:recipient, user) do
    # if the recipient can be deleted then it can also be archived
    can_delete?(:recipient, user)
  end
end
