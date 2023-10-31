defmodule BoilerPlate.EmailDeliveryChecker do
  alias BoilerPlate.Repo
  alias BoilerPlate.PackageAssignment
  alias BoilerPlate.User
  alias BoilerPlate.Requestor
  alias BoilerPlate.Recipient
  alias BoilerPlateWeb.NotificationController
  alias BoilerPlate.Notification
  import Ecto.Query
  require Logger

  @delivery_fault_secret "cAsKR2d3z84GKFwknD6QpXbly9/TYQilyP9p1CoE8m4XLn9pPtr7whfL+hTJyYFu"

  def clear_delivery_fault(recipient_id, secret) do
    if secret == @delivery_fault_secret do
      all_package_assignments =
        Repo.all(
          from pa in PackageAssignment,
            where:
              pa.recipient_id == ^recipient_id and
                pa.delivery_fault == true,
            select: pa
        )

      all_package_assignments
      |> Enum.each(fn pa ->
        cs = %{
          delivery_fault: false,
          fault_message: nil
        }

        # Get all Notificaitons
        notifications_to_be_removed =
          Repo.all(
            from noti in Notification,
              where:
                noti.title == "Delivery Failure" and
                  noti.assignment_id == ^pa.id,
              select: noti
          )

        notifications_to_be_removed
        |> Enum.each(fn noti ->
          notification = Repo.get(Notification, noti.id)
          noti_cs = Notification.changeset(notification, %{status: 1})
          Repo.update!(noti_cs)
        end)

        pa_cs = PackageAssignment.changeset(pa, cs)
        Repo.update!(pa_cs)
      end)
    end
  end

  def delivery_fault(
        package_assignment_id,
        delivery_fault,
        fault_message \\ nil,
        to_email,
        secret
      ) do
    if secret == @delivery_fault_secret do
      assignment = Repo.get(PackageAssignment, package_assignment_id)
      recipient_user = Repo.get(User, Repo.get(Recipient, assignment.recipient_id).user_id)

      if String.downcase(recipient_user.email) == String.downcase(to_email) do
        cs =
          PackageAssignment.changeset(assignment, %{
            delivery_fault: delivery_fault,
            fault_message: fault_message
          })

        Repo.update!(cs)

        doc_params = %{
          assignment_id: package_assignment_id,
          document_id: nil,
          document_type: nil
        }

        requestor_user = Repo.get(User, Repo.get(Requestor, assignment.requestor_id).user_id)

        NotificationController.add_notifications(
          assignment.company_id,
          doc_params,
          requestor_user,
          "A delivery issue has occured to the user: #{recipient_user.email}",
          "Delivery Failure",
          :delivery_fault
        )

        Logger.info(
          "Delivery issue for package assignment of ID: #{package_assignment_id} set to #{delivery_fault}"
        )
      end
    end
  end
end
