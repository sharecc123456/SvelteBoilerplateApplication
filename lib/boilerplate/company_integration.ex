alias BoilerPlate.Repo
import Ecto.Query

defmodule BoilerPlate.CompanyIntegration do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_integrations ["contacts_google"]

  schema "company_integrations" do
    field :data, :map
    field :flags, :integer
    field :status, :integer
    field :type, :string
    field :company_id, :id

    timestamps()
  end

  @doc false
  def changeset(company_integration, attrs) do
    company_integration
    |> cast(attrs, [:type, :data, :status, :flags, :company_id])
    |> validate_number(:flags, equal_to: 0)
    |> validate_number(:status, less_than: 2, greater_than_or_equal_to: 0)
    |> validate_inclusion(:type, @valid_integrations)
    |> validate_required([:type, :data, :status, :flags])
  end

  def type_valid?(t), do: Enum.member?(@valid_integrations, t)

  @doc false
  def create(attrs \\ []) do
    cs = changeset(%__MODULE__{}, attrs)

    if cs.valid? do
      case Repo.insert(cs) do
        {:ok, s} -> {:ok, s}
        {:error, e} -> {:ecto_error, e}
        _ -> {:error, :unknown}
      end
    else
      {:invalid_changeset, cs}
    end
  end

  def has_integration?(company, type) do
    query =
      from i in __MODULE__,
        where: i.company_id == ^company.id and i.status == 0 and i.type == ^type,
        select: i

    Repo.aggregate(query, :count, :id) > 0
  end

  def of(company, type) do
    Repo.get_by(__MODULE__, %{
      status: 0,
      type: type,
      company_id: company.id
    })
  end

  def update_integration(company, type, data) do
    integration = of(company, type)
    Repo.update!(changeset(integration, %{data: data}))
  end

  def set_for({:ok, _integration}, _company, _type) do
    # do nothing
  end

  def set_for(_ret, _company, _type) do
    raise ArgumentError, message: "failed to add an integration"
  end

  def all_of(company) do
    Repo.all(
      from ci in __MODULE__, where: ci.company_id == ^company.id and ci.status == 0, select: ci
    )
  end

  def deauthorize(company, type) do
    ssos =
      Repo.all(
        from sso in __MODULE__,
          where: sso.status == 0 and sso.company_id == ^company.id and sso.type == ^type,
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
