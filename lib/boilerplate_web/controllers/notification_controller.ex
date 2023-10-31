alias BoilerPlate.Repo
alias BoilerPlate.Company
alias BoilerPlate.DocumentRequest
alias BoilerPlate.PackageAssignment
alias BoilerPlate.Recipient
alias BoilerPlate.User
alias BoilerPlate.Notification
import Ecto.Query
use Timex

defmodule BoilerPlateWeb.NotificationController do
  use BoilerPlateWeb, :controller

  ###
  ### Notification Creators
  ###

  def add_document_expired_notification(type, company_id, doc_params, us_user, recipient_user) do
    # add expired doc in db
    document_type = doc_params.document_type
    request_id = doc_params.request_id
    due_date = doc_params.due_date
    checklist_name = doc_params.checklist_name

    req =
      if document_type == "request" do
        # request_id
        Repo.get(DocumentRequest, request_id)
      else
        raise ArgumentError, message: "invalid document type in ..."
      end

    message_prefix =
      "The document #{req.title} uploaded for checklist #{checklist_name} by #{recipient_user.email} of company #{recipient_user.organization}"

    message_postfix = "Expiration set on: #{due_date}"

    message =
      case type do
        :expired -> "#{message_prefix} is expired."
        :expiring_next_week -> "#{message_prefix} is expiring in a week."
        :expiring_next_month -> "#{message_prefix} is expiring in a month."
        _ -> ""
      end

    message = "#{message} #{message_postfix}"

    notification_type =
      case type do
        :expired -> :expired
        _ -> :expiring
      end

    notification_title = "Expiration"

    add_notifications(
      company_id,
      doc_params,
      us_user,
      message,
      notification_title,
      notification_type
    )
  end

  ###
  ### Internal API
  ###

  def add_notifications(company_id, doc_params, us_user, message, title, type) do
    assignment_id = doc_params.assignment_id
    document_type = doc_params.document_type
    document_id = doc_params.document_id

    company = Repo.get(Company, company_id)

    notif = %Notification{
      type: Atom.to_string(type),
      company_id: company.id,
      title: title,
      message: message,
      user_id: us_user.id,
      flags: 0,
      assignment_id: assignment_id,
      document_type: document_type,
      document_id: document_id
    }

    Repo.insert!(notif)
    :ok
  end

  # Internal Notification: Internal messages stemming from Boilerplate: outages, upgrades, etc.
  def add_internal_notification_to_companies(companies, message, title) do
    for company <- companies do
      add_internal_notification(company.id, message, title)
    end
  end

  defp add_internal_notification(company_id, message, title) do
    Repo.insert!(%Notification{
      type: "internal",
      company_id: company_id,
      title: title,
      message: message,
      user_id: 0,
      flags: 0,
      assignment_id: nil,
      document_type: nil,
      document_id: nil
    })

    :ok
  end

  ###
  ### Plug Handlers
  ###

  def get_notifications(conn, _params) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    company = get_current_requestor(conn, as: :company)

    if BoilerPlate.AccessPolicy.has_admin_access_to?(company, us_user) do
      company_notifications =
        Repo.all(
          from noti in Notification,
            where:
              noti.company_id == ^company.id and
                (noti.user_id == ^us_user.id or noti.user_id == 0) and noti.status == 0,
            select: noti,
            order_by: [desc: noti.inserted_at]
        )

      render(conn, "notifications.json", notifications: company_notifications)
    else
      conn |> put_status(403) |> text(:forbidden)
    end
  end

  def get_notifications_details(conn, %{"id" => id}) do
    notification = Repo.get(Notification, id)
    assignment = Repo.get(PackageAssignment, notification.assignment_id)

    recipient = Repo.get(Recipient, assignment.recipient_id)
    the_user = Repo.get(User, recipient.user_id)

    notification_details = %{
      company: recipient.organization,
      name: recipient.name,
      email: the_user.email,
      recipient_id: recipient.id
    }

    json(conn, notification_details)
  end

  def mark_notification_read(conn, %{"id" => id}) do
    notification = Repo.get(Notification, id)

    cs = Notification.changeset(notification, %{flags: 1})
    Repo.update!(cs)

    text(conn, "OK")
  end

  def archive_notification(conn, %{"id" => id}) do
    notification = Repo.get(Notification, id)

    cs = Notification.changeset(notification, %{status: 1})
    Repo.update!(cs)

    text(conn, "OK")
  end

  def get_unread_count(conn, _params) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    company = get_current_requestor(conn, as: :company)

    if BoilerPlate.AccessPolicy.has_admin_access_to?(company, us_user) do
      query =
        from noti in Notification,
          where: noti.user_id == ^us_user.id and noti.flags == 0,
          select: noti

      notification_count = BoilerPlate.Repo.aggregate(query, :count, :id)

      json(conn, %{count: notification_count, unread: notification_count > 0})
    else
      conn |> put_status(403) |> text(:forbidden)
    end
  end
end
