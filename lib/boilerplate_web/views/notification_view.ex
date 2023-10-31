alias BoilerPlate.Notification

defmodule BoilerPlateWeb.NotificationView do
  use BoilerPlateWeb, :view

  def render("notification.json", %{notification: notification}) do
    %{
      id: notification.id,
      type: notification.type,
      message: notification.message,
      title: notification.title,
      assignment_id: notification.assignment_id,
      read: Notification.flags_type_to_read_bool(notification.flags),
      company_id: notification.company_id,
      document_id: notification.document_id,
      inserted_at: notification.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D}T{0h24}:{0m}:{0s}Z")
    }
  end

  def render("notifications.json", %{notifications: notifications}) do
    render_many(notifications, BoilerPlateWeb.NotificationView, "notification.json",
      as: :notification
    )
  end
end
