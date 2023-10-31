import Bitwise

defmodule BoilerPlate.User do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias BoilerPlate.Repo
  alias BoilerPlate.Package
  alias BoilerPlate.PackageAssignment

  schema "users" do
    field :access_code, :string
    field :name, :string
    field :email, :string
    field :admin_of, :id
    field :company_id, :id
    field :current_package, :integer
    field :current_document_index, :integer
    field :username, :string
    field :password_hash, :string
    field :flags, :integer
    # Bit 0 => deleted?
    # Bit 1 => password reset OK? (when recipient)
    # Bit 2 => stripe ok?
    field :stripe_customer_id, :string
    field :organization, :string
    field :coupon, :integer
    field :plan, :string
    field :terms_accepted, :boolean
    field :verified, :boolean
    field :verification_code, :string
    field :phone_number, :string
    field :two_factor_state, :integer
    field :two_factor_data, :map, default: %{}
    field :api_key, :string, default: nil
    field :logins_count, :integer, default: 1
    field :text_signature, :string, default: ""

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :name,
      :email,
      :access_code,
      :company_id,
      :current_package,
      :current_document_index,
      :username,
      :password_hash,
      :flags,
      :stripe_customer_id,
      :organization,
      :coupon,
      :plan,
      :terms_accepted,
      :verified,
      :verification_code,
      :phone_number,
      :two_factor_state,
      :two_factor_data,
      :api_key,
      :logins_count,
      :text_signature
    ])
    |> validate_required([:name, :email, :company_id, :password_hash, :flags])
  end

  def user_type_to_atom(type) do
    case type do
      "recipient" -> :recipient
      "requestor" -> :requestor
      _ -> :unknown
    end
  end

  def is_hidden?(user) do
    (user.flags &&& 1) == 1
  end

  def two_factor_state?(user) do
    case user.two_factor_state do
      0 -> :not_setup
      1 -> :pending_first_verification
      2 -> :setup
      3 -> :app_first_verification
      4 -> :app_setup
      _ -> :unknown
    end
  end

  def update_two_factor_for(user, new_state) do
    ns =
      case new_state do
        :not_setup -> 0
        :pending_first_verification -> 1
        :setup -> 2
        :app_first_verification -> 3
        :app_setup -> 4
        _ -> raise "Invalid new_state in update_two_factor_for"
      end

    changeset(user, %{two_factor_state: ns})
  end

  def update_logins_count(user) do
    ns = user.logins_count + 1
    changeset(user, %{logins_count: ns})
  end

  # 10 characters or more
  # At least one lowercase letter
  # At least one uppercase letter
  # At least one number
  # At least one special characte
  def password_ok?(pwd) do
    cond do
      String.length(pwd) < 8 -> false
      # String.downcase(pwd) == pwd -> false
      # String.upcase(pwd) == pwd   -> false
      # not String.contains?(pwd, ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]) -> false
      # not String.contains?(pwd, ["!", "@", "#", "$", "%", "^", "&", "*", "(", ")", "[", "]", "-", "_", "+", "=", "|", "/", "\\", ".", ",", "<", ">", "'", "{", "}", "~", "`"]) -> false
      True -> true
    end
  end

  def password_requirement_text() do
    "minimum 8 characters"
  end

  def assignments_of(user) do
    Repo.all(
      from pa in PackageAssignment,
        where:
          pa.status == 0 and
            pa.recipient_id == ^user.id,
        select: pa
    )
  end

  def archived_assignments_of(user) do
    Repo.all(
      from pa in PackageAssignment,
        where:
          pa.status == 1 and
            pa.recipient_id == ^user.id,
        select: pa
    )
  end

  def assigned_packages_of(user) do
    assignments_of(user)
    |> Enum.map(& &1.package_id)
    |> Enum.map(&Repo.get(Package, &1))
  end

  # Return the password reset hash for a given user
  def password_reset_hash_for(user) do
    str = "hello_boilerplate_#{user.id}_#{user.password_hash}"
    :crypto.hash(:sha256, str) |> Base.encode16() |> String.downcase()
  end

  # Return all users that are associated with
  # the company passed in the argument
  def all_associated_with(company) do
    cid = company.id

    Repo.all(
      from u in BoilerPlate.User,
        order_by: u.inserted_at,
        where: u.admin_of == ^cid or u.company_id == ^cid,
        select: u
    )
    |> Enum.filter(&(!BoilerPlate.User.is_hidden?(&1)))
  end

  def exists?(email) do
    query = from u in BoilerPlate.User, where: u.email == ^email, select: u
    Repo.aggregate(query, :count, :id) > 0
  end

  def all_active_users_for(company) do
    BoilerPlate.Repo.all(
      from u in BoilerPlate.User,
        join: r in BoilerPlate.Requestor,
        on: r.user_id == u.id,
        select: u,
        where:
          r.company_id == ^company.id and
            r.status == 0
    )
  end

  def user_exists_in_company?(user, company, email) do
    is_existing =
      Repo.one(
        from u in BoilerPlate.User,
          where: u.email == ^email and u.company_id == ^company.id and u.id != ^user.id,
          select: u
      )

    is_existing != nil
  end

  def new_password(length) do
    alphabet = Enum.to_list(?a..?z) ++ Enum.to_list(?0..?9)
    for _ <- 1..length, into: "", do: <<Enum.random(alphabet)>>
  end

  def hash_password(pwd) do
    :crypto.hash(:sha256, pwd) |> Base.encode16() |> String.downcase()
  end
end

defimpl FunWithFlags.Actor, for: BoilerPlate.User do
  def id(user) do
    "user:#{user.id}"
  end
end
