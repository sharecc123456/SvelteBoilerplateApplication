alias BoilerPlate.Repo

defmodule BoilerPlate.Webhook do
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset

  schema "webhooks" do
    field :events, {:array, :string}
    field :flags, :integer
    field :name, :string
    field :shared_secret, :string
    field :url, :string
    field :status, :integer
    field :company_id, :id

    timestamps()
  end

  @doc false
  def changeset(webhook, attrs) do
    webhook
    |> cast(attrs, [:name, :events, :shared_secret, :url, :status, :flags])
    |> validate_required([:name, :events, :shared_secret, :url, :status, :flags])
  end

  # list of valid events
  def valid_event?(event) when event == "checklist.create", do: true
  def valid_event?(_), do: false

  def fire(event, company_id, data) do
    # Check if this event is registered for the company
    webhook =
      Repo.one(
        from w in BoilerPlate.Webhook,
          where: ^event in w.events and w.company_id == ^company_id,
          select: w
      )

    if webhook != nil do
      # Encode the data into JSON
      js = Poison.encode!(data)

      # Generate the HMAC
      signature =
        :crypto.mac(:hmac, :sha256, webhook.shared_secret, js)
        |> Base.encode16()
        |> String.downcase()

      # Send the data to the URL
      headers = [
        {"X-Boilerplate-HMAC-Signature", signature},
        {"X-Boilerplate-WebHook-Id", "#{webhook.id}"},
        {"X-Boilerplate-WebHook-Event", event},
        {"X-Boilerplate-WebHook-Delivery", UUID.uuid4()},
        {"User-Agent", "Boilerplate-HookShot/#{Application.get_env(:boilerplate, :version)}"},
        {"Content-Type", "application/json"}
      ]

      HTTPoison.post(webhook.url, js, headers)
    end
  end
end
