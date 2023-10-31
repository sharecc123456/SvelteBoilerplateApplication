alias BoilerPlate.Repo
import Ecto.Query

defmodule BoilerPlate.TwoFactorComputer do
  use Ecto.Schema
  import Ecto.Changeset

  schema "two_factor_computers" do
    field :ip_hash, :string
    field :user_id, :integer
    field :expires, :date

    timestamps()
  end

  @doc false
  def changeset(package, attrs) do
    package
    |> cast(attrs, [:ip_hash, :user_id, :expires])
    |> validate_required([:ip_hash, :user_id, :expires])
  end

  def remember_this_computer_for(conn, user) do
    hashed_ip =
      :crypto.hash(:sha256, conn.remote_ip |> inspect()) |> Base.encode16() |> String.downcase()

    tfc = %BoilerPlate.TwoFactorComputer{
      ip_hash: hashed_ip,
      user_id: user.id,
      expires: Date.utc_today() |> Date.add(1)
    }

    Repo.insert!(tfc)
  end

  def is_this_remembered_for?(conn, user) do
    hashed_ip =
      :crypto.hash(:sha256, conn.remote_ip |> inspect()) |> Base.encode16() |> String.downcase()

    today_date = Date.utc_today()

    query =
      from tfc in BoilerPlate.TwoFactorComputer,
        where:
          tfc.ip_hash == ^hashed_ip and
            tfc.user_id == ^user.id and
            tfc.expires > ^today_date,
        select: tfc

    Repo.aggregate(query, :count, :id) > 0
  end
end
