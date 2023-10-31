alias BoilerPlate.Repo
alias BoilerPlate.User
import Ecto.Query

defmodule BoilerPlate.UserSSO do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_user_ssos ["google"]

  schema "user_sso" do
    field :data, :map
    field :flags, :integer
    field :status, :integer
    field :type, :string
    field :user_id, :id

    timestamps()
  end

  @doc false
  def changeset(user_sso, attrs) do
    user_sso
    |> cast(attrs, [:type, :data, :status, :flags])
    |> validate_number(:status, less_than: 2, greater_than_or_equal_to: 0)
    |> validate_inclusion(:type, @valid_user_ssos)
    |> validate_required([:type, :data, :status, :flags])
  end

  def type_valid?(t), do: Enum.member?(@valid_user_ssos, t)

  def can_connect?(_email, _type, _meta) do
    true
  end

  defp do_connect(user_id, type, meta) do
    Repo.insert!(%__MODULE__{
      data: meta,
      flags: 0,
      status: 0,
      type: type,
      user_id: user_id
    })
  end

  def connect(email, type, meta) do
    connect_to(Repo.get_by(User, %{email: email}), type, meta)
  end

  def connect_to(nil, type, meta) do
    # Try matching via sub
    sub = meta.sub

    ssos =
      Repo.all(
        from sso in __MODULE__,
          where:
            sso.status == 0 and sso.type == ^type and
              fragment("? ->> 'sub' = ?", sso.data, ^sub),
          select: sso
      )

    cond do
      length(ssos) == 0 ->
        {:err, :no_user}

      length(ssos) == 1 ->
        sso = Enum.at(ssos, 0)
        {:ok, Repo.get(User, sso.user_id)}

      length(ssos) > 1 ->
        {:err, :other_account}
    end
  end

  # The User exists, check if there is an SSO.
  def connect_to(user, type, meta) do
    ssos =
      Repo.all(
        from sso in __MODULE__,
          where: sso.status == 0 and sso.type == ^type and sso.user_id == ^user.id,
          select: sso
      )

    cond do
      length(ssos) == 0 ->
        # The account didn't have SSO tied, so tie it and let it go.
        do_connect(user.id, type, meta)
        {:ok, user}

      length(ssos) == 1 ->
        # An SSO record exists for this user. We should check if the subject
        # matches the user's record.
        sso = Enum.at(ssos, 0)

        if meta.sub == sso.data["sub"] do
          # Subject matches, log them in.
          {:ok, user}
        else
          # Subject mismatch, don't log them in.
          {:err, :other_account}
        end

      length(ssos) > 1 ->
        # Too many SSOs for this user and this type.
        {:err, :other_account}
    end
  end

  def all_of(user) do
    Repo.all(
      from sso in __MODULE__, where: sso.status == 0 and sso.user_id == ^user.id, select: sso
    )
  end

  def deauthorize(user, type) do
    ssos =
      Repo.all(
        from sso in __MODULE__,
          where: sso.status == 0 and sso.user_id == ^user.id and sso.type == ^type,
          select: sso
      )

    cond do
      Enum.empty?(ssos) ->
        {:error, :not_found}

      length(ssos) > 1 ->
        {:error, :too_many}

      true ->
        Enum.each(ssos, fn sso ->
          Repo.update!(changeset(sso, %{status: 1}))
        end)

        :ok
    end
  end
end
