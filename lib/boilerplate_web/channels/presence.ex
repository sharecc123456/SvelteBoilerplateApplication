defmodule BoilerPlateWeb.Presence do
  @moduledoc """
  Provides presence tracking to channels and processes.

  See the [`Phoenix.Presence`](https://hexdocs.pm/phoenix/Phoenix.Presence.html)
  docs for more details.
  """
  use Phoenix.Presence, otp_app: :boilerplate,
                        pubsub_server: BoilerPlate.PubSub

  # def track_user_join(socket, user) do
  #   Presence.track(socket, user.id, %{})
  # end
end
