alias BoilerPlate.User
alias BoilerPlate.Repo
alias BoilerPlate.Requestor
alias BoilerPlate.Recipient
import Ecto.Query

# Defines access policies
defmodule BoilerPlate.AccessPolicy do
  # does @user have access to @company?
  def has_access_to?(:company, company, user) do
    has_admin_access_to?(company, user) or
      has_normal_access_to?(company, user)
  end

  # Does @user have admin access to @company?
  def has_admin_access_to?(company, user) do
    requestor =
      Repo.one(
        from r in Requestor,
          where: r.company_id == ^company.id and r.user_id == ^user.id and r.status == 0,
          select: r
      )

    requestor != nil
  end

  def has_normal_access_to?(company, user) do
    recipient =
      Repo.all(
        from r in Recipient,
          where: r.user_id == ^user.id and r.status == 0 and r.company_id == ^company.id,
          select: r
      )

    requestor =
      Repo.all(
        from r in Requestor,
          where: r.user_id == ^user.id and r.status == 0 and r.company_id == ^company.id,
          select: r
      )

    length(recipient) > 0 or length(requestor) > 0
  end

  #
  # HELPERS
  #

  def can_we_access?(:company, company, conn) do
    user = Repo.get(User, BoilerPlate.Guardian.Plug.current_resource(conn).id)
    has_normal_access_to?(company, user)
  end

  def can_we_admin_company?(conn, company) do
    user = Repo.get(User, BoilerPlate.Guardian.Plug.current_resource(conn).id)
    has_admin_access_to?(company, user)
  end

  def has_admin_access_to_fill_type_user?(company, user, fill_type) do
    case fill_type do
      "requestor" -> has_admin_access_to?(company, user)
      "review" -> has_admin_access_to?(company, user)
      "recipient" ->
        Repo.get_by(Recipient, %{user_id: user.id, status: 0, company_id: company.id}) != nil
      _ ->
          raise "Invalid fill type user tried access"
          false
    end
  end
end
