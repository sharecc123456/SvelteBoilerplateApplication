defmodule BoilerPlateWeb.RecipientIACFillChannel do
  # create the channel that the client communicates presence over
  use BoilerPlateWeb, :channel
  alias BoilerPlateWeb.Presence

  intercept ["presence_diff"]

  @doc """
  Join a iac_fill channel topic through a socket with params %{"fillType" => user_type} under topic "iac_fill:<<iac_assigned_id>>"
  Once the user has joined the channel, send a message to current process with :after_join atom and user_type as contents
  """
  def join("iac_fill:" <> iac_assigned_id, %{"fillType" => user_type}, socket) do
    send(self(), {:after_join, user_type})

    {:ok, %{iac_assigned_id: iac_assigned_id}, assign(socket, :iac_assigned_id, iac_assigned_id)}
  end

  @doc """
    Adds the new user joining the channel to the Presence store and track the connection.
  """
  def handle_info({:after_join, user_type}, socket) do
    Presence.track(socket, user_type, %{
      user_type: user_type,
      iac_assigned_id: socket.assigns.iac_assigned_id
    })

    # The client connected to the topic listens for the "presence_state" event.
    # provides updated list of active users.
    push socket, "presence_state", Presence.list(socket)

    {:noreply, socket}
  end

  @doc """
    handles incoming event requestor_update. handle_in/3
    notifies all other iac_fill: subscribers og the new message with broadcast!/3
  """
  def handle_in("requestor_update", %{}, socket) do
    broadcast! socket, "requestor_edit_complete", %{}
    {:noreply, socket}
  end

  def handle_in("recipient_submission", %{}, socket) do
    broadcast! socket, "recipient_fill_complete", %{}
    {:noreply, socket}
  end

  @doc """
    presence_diff event is triggered when any active user leaves the channel topic.
    # provides updated list of active users to all connected to the topic.
  """
  def handle_out("presence_diff", params, socket) do
    push socket, "presence_diff", params
    {:noreply, socket}
  end
end
