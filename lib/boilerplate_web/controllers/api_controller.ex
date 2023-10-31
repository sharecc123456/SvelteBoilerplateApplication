alias BoilerPlate.Repo
alias BoilerPlate.User
alias BoilerPlate.UserSSO
alias BoilerPlate.AdhocLink
alias BoilerPlate.Company
alias BoilerPlate.CompanyIntegration
alias BoilerPlate.IACDocument
alias BoilerPlate.IACMasterForm
alias BoilerPlate.IACAssignedForm
alias BoilerPlate.IACField
alias BoilerPlate.IACSignature
alias BoilerPlate.RawDocument
alias BoilerPlate.RawDocumentCustomized
alias BoilerPlate.Package
alias BoilerPlate.PackageAssignment
alias BoilerPlate.Cabinet
alias BoilerPlate.Document
alias BoilerPlate.PackageContents
alias BoilerPlate.Recipient
alias BoilerPlate.Requestor
alias BoilerPlate.DocumentRequest
alias BoilerPlate.RequestCompletion
alias BoilerPlate.Email
alias BoilerPlate.FilterEngine
alias BoilerPlate.QueryEngine
alias BoilerPlate.Helpers
alias BoilerPlate.FileCleanerUtils
alias BoilerPlateWeb.FormController
alias BoilerPlate.CustomDateTimex
alias BoilerPlate.FileCleanerUtils
alias BoilerPlate.FileHelpers
alias BoilerPlate.DocumentTag
alias BoilerPlate.AssignmentUtils
alias BoilerPlate.WeeklyStatusChecker
alias BoilerPlate.RecipientTag
import Ecto.Query
import Bitwise
require Logger

defmodule BoilerPlateWeb.ApiController do
  alias BoilerPlateWeb.IACController
  alias BoilerPlateWeb.RecipientController
  use BoilerPlateWeb, :controller

  @storage_mod Application.compile_env(:boilerplate, :storage_backend, StorageAwsImpl)

  def get_token(conn, %{"api-key" => api_key}) do
    if api_key == nil do
      conn |> put_status(400) |> text("need api key")
    else
      u = Repo.get_by(User, %{api_key: api_key})

      if u == nil do
        conn |> put_status(404) |> text("bad api key")
      else
        is_admin? =
          Repo.aggregate(
            from(r in Requestor, where: r.user_id == ^u.id and r.status == 0, select: r),
            :count,
            :id
          ) > 0

        conn =
          conn
          |> BoilerPlate.Guardian.Plug.sign_in(
            u,
            %{blptreq: is_admin?, two_factor_approved: true},
            ttl: {720, :minute}
          )

        json(conn, BoilerPlate.Guardian.Plug.current_token(conn))
      end
    end
  end

  def user_restrict(conn, %{"companyId" => id}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    recipient =
      Repo.one(
        from r in Recipient,
          where: r.user_id == ^us_user.id and r.status == 0 and r.company_id == ^id,
          select: r
      )

    requestor =
      Repo.one(
        from r in Requestor,
          where: r.user_id == ^us_user.id and r.status == 0 and r.company_id == ^id,
          select: r
      )

    current_claims = BoilerPlate.Guardian.Plug.current_claims(conn)

    claims =
      cond do
        current_claims == nil and recipient == nil and requestor == nil ->
          %{}

        current_claims == nil and recipient != nil and requestor == nil ->
          %{"recipient_id" => recipient.id}

        current_claims == nil and recipient != nil and requestor != nil ->
          %{"recipient_id" => recipient.id, "requestor_id" => requestor.id}

        current_claims == nil and recipient == nil and requestor != nil ->
          %{"requestor_id" => requestor.id}

        current_claims != nil and recipient == nil and requestor == nil ->
          current_claims

        current_claims != nil and recipient != nil and requestor == nil ->
          Map.merge(current_claims, %{"recipient_id" => recipient.id})

        current_claims != nil and recipient == nil and requestor != nil ->
          Map.merge(current_claims, %{"requestor_id" => requestor.id})

        current_claims != nil and recipient != nil and requestor != nil ->
          Map.merge(current_claims, %{
            "recipient_id" => recipient.id,
            "requestor_id" => requestor.id
          })
      end

    conn =
      conn
      |> fetch_session()
      |> BoilerPlate.Guardian.Plug.sign_out()
      |> BoilerPlate.Guardian.Plug.sign_in(us_user, claims, ttl: {720, :minute})

    json(conn, %{status: :ok, new_token: BoilerPlate.Guardian.Plug.current_token(conn)})
  end

  def user_lookup(conn, %{"email" => email}) do
    email = String.trim(String.downcase(email))
    user = Repo.get_by(User, %{email: email})

    if user != nil do
      json(conn, %{exists: true, id: user.id, name: user.name})
    else
      json(conn, %{exists: false})
    end
  end

  def do_login_sso(conn, %{"sso" => "google", "credential" => jwt}) do
    with {:ok, claims} <- Crypto.GoogleJWTManager.verify_and_validate(jwt) do
      email = claims["email"]
      email_verified = claims["email_verified"]

      cond do
        not email_verified ->
          conn |> put_status(400) |> json(%{error: :sso_invalid})

        UserSSO.can_connect?(email, "google", %{sub: claims["sub"]}) ->
          case UserSSO.connect(email, "google", %{sub: claims["sub"]}) do
            {:ok, user} ->
              # TODO extract this to some better function.
              do_login(conn, %{"email" => user.email, "hashedPassword" => user.password_hash})

            {:err, :other_account} ->
              conn |> put_status(400) |> json(%{error: :sso_already})

            {:err, :no_user} ->
              conn |> put_status(400) |> json(%{error: :sso_no_user})
          end

        true ->
          conn |> put_status(400) |> json(%{error: :sso_no_user})
      end
    else
      _ ->
        conn |> put_status(400) |> json(%{error: :sso_bad_token})
    end
  end

  def do_login(conn, %{"email" => email, "hashedPassword" => hashed_password}) do
    email = String.trim(String.downcase(email))

    user =
      Repo.one(
        from u in User,
          where: u.email == ^email and u.password_hash == ^hashed_password,
          select: u
      )

    # Check if OK to continue
    conn = conn |> fetch_session()
    attempts = conn |> get_session(:count_attempt_login) || 0
    attempt_expiry = conn |> get_session(:count_attempt_login_expiry)
    current_ts = DateTime.utc_now() |> DateTime.to_unix()

    {ok_to_continue, att} =
      cond do
        attempts <= 10 ->
          {true, attempts}

        attempt_expiry != nil and attempt_expiry < current_ts ->
          {true, 0}

        True ->
          {false, attempts}
      end

    attempts = att

    if ok_to_continue do
      conn =
        conn
        |> put_session(:count_attempt_login, attempts + 1)

      if user != nil do
        current_claims = BoilerPlate.Guardian.Plug.current_claims(conn)
        user = Repo.update!(User.update_logins_count(user))

        recipient_count =
          Repo.aggregate(
            from(r in Recipient, where: r.user_id == ^user.id and r.status == 0, select: r),
            :count,
            :id
          )

        requestor_count =
          Repo.aggregate(
            from(r in Requestor, where: r.user_id == ^user.id and r.status == 0, select: r),
            :count,
            :id
          )

        is_admin? = requestor_count > 0

        tfa_remembered? = BoilerPlate.TwoFactorComputer.is_this_remembered_for?(conn, user)

        claims =
          (current_claims || %{})
          |> Map.put("two_factor_approved", tfa_remembered?)
          |> Map.put("blptreq", is_admin?)

        conn =
          conn
          |> fetch_session()
          |> delete_session(:count_attempt_login)
          |> delete_session(:count_attempt_login_expiry)
          |> BoilerPlate.Guardian.Plug.sign_out()
          |> BoilerPlate.Guardian.Plug.sign_in(user, claims, ttl: {720, :minute})

        is_first_time_login? = is_admin? and user.logins_count == 1

        cond do
          is_first_time_login? ->
            json(conn, %{
              uid: user.id,
              email: user.email,
              lhash: user.password_hash,
              status: :reset_password
            })

          requestor_count > 0 and recipient_count > 0 ->
            json(conn, %{
              id: user.id,
              name: user.name,
              status: :midlogin,
              choose_requestor: requestor_count > 1
            })

          requestor_count == 0 and recipient_count > 1 ->
            json(conn, %{id: user.id, name: user.name, status: :recipientc})

          requestor_count > 1 and recipient_count == 0 ->
            json(conn, %{id: user.id, name: user.name, status: :requestorc})

          requestor_count == 1 ->
            json(conn, %{id: user.id, name: user.name, status: :requestor})

          recipient_count == 1 ->
            json(conn, %{id: user.id, name: user.name, status: :recipient})

          True ->
            json(conn, %{id: user.id, name: user.name, status: :failed})
        end
      else
        if User.exists?(email) do
          conn
          |> put_status(404)
          |> json(%{
            error: :invalid_password
          })
        else
          conn
          |> put_status(404)
          |> json(%{
            error: :invalid_email
          })
        end
      end
    else
      # Too many failed attempts have been made
      conn
      |> put_session(
        :count_attempt_login_expiry,
        300 + (DateTime.utc_now() |> DateTime.to_unix())
      )
      |> put_status(403)
      |> json(%{
        error: :too_many_attempts
      })
    end
  end

  # TODO
  defp iac_setup_for_customization?(_doc, rdc) do
    if rdc == nil do
      false
    else
      IACDocument.setup_for?(:raw_document_customized, rdc)
    end
  end

  ###################
  ####           ####
  ####           ####
  #### API CALLS ####
  ####           ####
  ####           ####
  ###################

  defp make_assignments_of(recipient) do
    final_assign = do_make_assignments_of(User.assignments_of(recipient), recipient)

    # default sort by package assignment date in desc
    Enum.sort(final_assign, fn a, b ->
      case NaiveDateTime.compare(
             Timex.parse!(a.received_date.date, "{YYYY}-{M}-{D} {0h24}:{0m}:{0s}"),
             Timex.parse!(b.received_date.date, "{YYYY}-{M}-{D} {0h24}:{0m}:{0s}")
           ) do
        :gt -> true
        _ -> false
      end
    end)
  end

  defp do_make_assignments_of(assignments, recipient) do
    for assignment <- assignments do
      contents = Repo.get(PackageContents, assignment.contents_id)
      pkg = Repo.get(Package, assignment.package_id)
      requestor = Repo.get(Requestor, assignment.requestor_id)

      document_requests =
        BoilerPlate.AssignmentUtils.get_checklist_document_requests(
          assignment,
          recipient,
          contents
        )

      file_requests =
        BoilerPlate.AssignmentUtils.get_checklist_file_requests(assignment, recipient, contents)

      forms = FormController.get_forms_for_contents(contents.id)

      a_status = AssignmentUtils.assignment_status(document_requests, file_requests, forms)

      BoilerPlate.AssignmentUtils.build_assignment_response(
        contents,
        assignment,
        pkg,
        requestor,
        a_status,
        document_requests,
        file_requests,
        forms,
        %{}
      )
    end
  end

  def assignments_info(conn, _params) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    recipient = get_current_recipient(conn)

    if us_user != nil and recipient != nil do
      data = make_assignments_of(recipient)
      json(conn, data)
    else
      json(conn, [])
    end
  end

  def get_assignment_with_id(conn, params) do
    id = params["id"]
    assignment = Repo.get(PackageAssignment, id)
    company = Repo.get(Company, assignment.company_id)

    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    if BoilerPlate.AccessPolicy.has_admin_access_to?(company, us_user) do
      assignment_map = Map.from_struct(assignment) |> Map.delete(:__meta__)
      conn |> json(assignment_map)
    else
      conn |> put_status(403) |> text("Forbidden")
    end
  end

  defp mfa_send_first_text(us_user) do
    headers = %{
      "content-type": "application/x-www-form-urlencoded"
    }

    req_body = URI.encode_query(%{"To" => us_user.phone_number, "Channel" => "sms"})

    HTTPoison.post(
      "https://verify.twilio.com/v2/Services/#{Application.get_env(:boilerplate, :twilio_service)}/Verifications",
      req_body,
      headers,
      hackney: [
        basic_auth:
          {"#{Application.get_env(:boilerplate, :twilio_account_sid)}",
           "#{Application.get_env(:boilerplate, :twilio_auth_token)}"}
      ]
    )

    Repo.update!(User.update_two_factor_for(us_user, :pending_first_verification))
  end

  defp mfa_resend(us_user) do
    headers = %{
      "content-type": "application/x-www-form-urlencoded"
    }

    req_body = URI.encode_query(%{"To" => us_user.phone_number, "Channel" => "sms"})

    HTTPoison.post(
      "https://verify.twilio.com/v2/Services/#{Application.get_env(:boilerplate, :twilio_service)}/Verifications",
      req_body,
      headers,
      hackney: [
        basic_auth:
          {"#{Application.get_env(:boilerplate, :twilio_account_sid)}",
           "#{Application.get_env(:boilerplate, :twilio_auth_token)}"}
      ]
    )
  end

  defp mfa_verify_code(us_user, vc) do
    if FunWithFlags.enabled?(:mfa_testing) do
      :ok
    else
      headers = %{
        "content-type": "application/x-www-form-urlencoded"
      }

      req_body = URI.encode_query(%{"To" => us_user.phone_number, "Code" => "#{vc}"})

      {:ok, response} =
        HTTPoison.post(
          "https://verify.twilio.com/v2/Services/#{Application.get_env(:boilerplate, :twilio_service)}/VerificationCheck",
          req_body,
          headers,
          hackney: [
            basic_auth:
              {"#{Application.get_env(:boilerplate, :twilio_account_sid)}",
               "#{Application.get_env(:boilerplate, :twilio_auth_token)}"}
          ]
        )

      status = Poison.decode!(response.body)["status"]

      IO.inspect(Poison.decode!(response.body))

      if status == "approved" do
        :ok
      else
        :failure
      end
    end
  end

  # TODO(lev): cross check user id?
  def user_handle_mfa(conn, %{"id" => _user_id, "state" => new_state, "data" => data}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    case new_state do
      0 ->
        Repo.update!(User.update_two_factor_for(us_user, :not_setup))
        text(conn, "OK")

      1 ->
        # Pending First Verification
        mfa_send_first_text(us_user)
        text(conn, "OK")

      2 ->
        # Verify Setup Code
        code = data["code"]

        case mfa_verify_code(us_user, code) do
          :ok ->
            Repo.update!(User.update_two_factor_for(us_user, :setup))
            text(conn, "OK")

          _ ->
            conn |> put_status(400) |> text("OK")
        end

      11 ->
        # Verify Code
        code = data["code"]
        remember = data["remember"] || false

        if User.two_factor_state?(us_user) == :setup do
          case mfa_verify_code(us_user, code) do
            :ok ->
              if remember do
                BoilerPlate.TwoFactorComputer.remember_this_computer_for(conn, us_user)
              end

              current_claims = BoilerPlate.Guardian.Plug.current_claims(conn)

              claims =
                (current_claims || %{})
                |> Map.put("two_factor_approved", true)

              conn
              |> fetch_session()
              |> delete_session(:count_attempt_login)
              |> delete_session(:count_attempt_login_expiry)
              |> BoilerPlate.Guardian.Plug.sign_out()
              |> BoilerPlate.Guardian.Plug.sign_in(Repo.get(User, us_user.id), claims,
                ttl: {720, :minute}
              )
              |> text("OK")

            _ ->
              conn |> put_status(400) |> text("BAD")
          end
        end

        if User.two_factor_state?(us_user) == :app_setup do
          {:ok, secret} = us_user.two_factor_data["app_secret"] |> Base.decode16()
          time = System.os_time(:second)

          if NimbleTOTP.valid?(secret, code, time: time) or
               NimbleTOTP.valid?(secret, code, time: time - 30) do
            if remember do
              BoilerPlate.TwoFactorComputer.remember_this_computer_for(conn, us_user)
            end

            current_claims = BoilerPlate.Guardian.Plug.current_claims(conn)

            claims =
              (current_claims || %{})
              |> Map.put("two_factor_approved", true)

            conn
            |> fetch_session()
            |> delete_session(:count_attempt_login)
            |> delete_session(:count_attempt_login_expiry)
            |> BoilerPlate.Guardian.Plug.sign_out()
            |> BoilerPlate.Guardian.Plug.sign_in(Repo.get(User, us_user.id), claims,
              ttl: {720, :minute}
            )
            |> text("OK")
          else
            conn |> put_status(400) |> text("BAD")
          end
        end

      10 ->
        # Resend
        if User.two_factor_state?(us_user) != :app_setup and
             not FunWithFlags.enabled?(:mfa_testing) do
          mfa_resend(us_user)
        end

        text(conn, "OK")

      12 ->
        # Ask for QR data
        if User.two_factor_state?(us_user) == :setup do
          raise ArgumentError,
            message:
              "user id #{us_user.id} in MFA state #{User.two_factor_state?(us_user)} asking for MFA #12"
        end

        # Generate and save a secret
        secret = NimbleTOTP.secret()

        Repo.update!(
          User.changeset(us_user, %{two_factor_data: %{app_secret: secret |> Base.encode16()}})
        )

        uri = NimbleTOTP.otpauth_uri("Boilerplate", secret, issuer: "BoilerplateINC")
        conn |> json(%{uri: uri})

      13 ->
        code = data["code"]

        # Verify QR setup code
        if User.two_factor_state?(us_user) != :not_setup do
          raise ArgumentError,
            message:
              "user id #{us_user.id} in MFA state #{User.two_factor_state?(us_user)} asking for MFA #13"
        end

        {:ok, secret} = us_user.two_factor_data["app_secret"] |> Base.decode16()
        time = System.os_time(:second)

        if NimbleTOTP.valid?(secret, code, time: time) or
             NimbleTOTP.valid?(secret, code, time: time - 30) do
          Repo.update!(User.update_two_factor_for(us_user, :app_setup))
          text(conn, "OK")
        else
          conn |> put_status(400) |> text("BAD")
        end

      _ ->
        conn |> put_status(400) |> text("Invalid Request")
    end
  end

  def user_update_profile(conn, %{"id" => user_id, "phone" => phone}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    if Integer.to_string(us_user.id) != user_id do
      conn |> put_status(403) |> text("forbidden")
    else
      cs = User.changeset(us_user, %{phone_number: phone})
      Repo.update!(cs)
      text(conn, "OK")
    end
  end

  def user_me(conn, params) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    is_recipient = params["type"] == "recipient" || false

    if is_recipient do
      user_me_recipient(conn, us_user)
    else
      user_me_requestor(conn, us_user)
    end
  end

  def user_me_requestor(conn, us_user) do
    requestor = get_current_requestor(conn)

    if requestor != nil do
      render(conn, "user_me.json",
        requestor: requestor,
        user: us_user,
        user_sso: UserSSO.all_of(us_user)
      )
    else
      conn |> put_status(404) |> text("No such requestor")
    end
  end

  def user_me_recipient(conn, us_user) do
    recipient = get_current_recipient(conn)

    if recipient != nil do
      render(conn, "user_me.json",
        recipient: recipient,
        user: us_user,
        user_sso: UserSSO.all_of(us_user)
      )
    else
      conn |> put_status(404) |> text("No such recipient")
    end
  end

  def user_companies(conn, _params) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    recipient_companies =
      Repo.all(
        from r in Recipient,
          join: ca in Company,
          on: ca.id == r.company_id,
          where: r.status == 0 and r.user_id == ^us_user.id,
          order_by: [asc: ca.name],
          select: ca
      )
      |> Enum.uniq_by(& &1.id)

    requestor_companies =
      Repo.all(
        from r in Requestor,
          join: ca in Company,
          on: ca.id == r.company_id,
          where: r.status == 0 and r.user_id == ^us_user.id,
          order_by: [asc: ca.name],
          select: ca
      )
      |> Enum.uniq_by(& &1.id)

    crcn =
      case get_current_recipient(conn) do
        nil -> nil
        recp -> Repo.get(Company, recp.company_id).name
      end

    reqc = get_current_requestor(conn, as: :company)

    render(conn, "user_companies.json",
      uid: us_user.id,
      current_recipient_company_name: crcn,
      current_requestor_company_name:
        if reqc != nil do
          reqc.name
        else
          0
        end,
      current_requestor_company_id:
        if reqc != nil do
          reqc.id
        else
          0
        end,
      recipient_companies: recipient_companies,
      requestor_companies: requestor_companies
    )
  end

  def requestor_get_company_info(conn, _params) do
    requestor = get_current_requestor(conn)

    if requestor == nil do
      conn |> put_status(403) |> text("Forbidden")
    else
      company = Repo.get(Company, requestor.company_id)

      requestors =
        Repo.all(
          from r in Requestor,
            join: u in User,
            on: r.user_id == u.id,
            where: r.status == 0 and r.company_id == ^company.id,
            select: r
        )

      render(conn, "company_info.json",
        company: company,
        requestors: requestors,
        integrations: CompanyIntegration.all_of(company)
      )
    end
  end

  def recipient_fillin_datarequest(conn, %{
        "id" => id,
        "text" => text,
        "recipientId" => _rid,
        "assignmentId" => aid
      }) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    assignment = Repo.get(PackageAssignment, aid)

    recipient =
      Repo.one(
        from r in Recipient,
          where:
            r.status == 0 and r.user_id == ^us_user.id and r.company_id == ^assignment.company_id,
          select: r
      )

    res =
      BoilerPlateWeb.UserController.api_fillin_user_request(
        us_user,
        recipient.id,
        assignment.id,
        id,
        text
      )

    if res == :ok do
      BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, recipient.id)
      text(conn, "OK")
    else
      conn |> put_status(500) |> text(res)
    end
  end

  def recipient_done_taskrequest(conn, %{
        "recipientId" => rid,
        "assignmentId" => aid,
        "taskId" => id
      }) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    res =
      BoilerPlateWeb.UserController.api_mark_done_taskrequest(
        us_user,
        rid,
        aid,
        id
      )

    if res == :ok do
      BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, rid)
      text(conn, "OK")
    else
      conn |> put_status(500) |> text(res)
    end
  end

  def requestor_manual_request_upload(conn, %{"id" => id, "assignId" => assignId, "file" => file}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    assignment = Repo.get(PackageAssignment, assignId)
    requestor = get_current_requestor(conn)

    case BoilerPlateWeb.UserController.api_manual_upload(
           requestor,
           us_user,
           assignment.recipient_id,
           assignment.id,
           id,
           file,
           :request
         ) do
      :ok ->
        BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, assignment.recipient_id)
        text(conn, "OK")

      :forbidden ->
        conn |> put_status(400) |> json(%{error: :forbidden})

      :bad_file ->
        conn |> put_status(400) |> json(%{error: :bad_file})
    end
  end

  def requestor_manual_document_upload(conn, %{"id" => id, "assignId" => assignId, "file" => file}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    requestor = get_current_requestor(conn)
    assignment = Repo.get(PackageAssignment, assignId)

    case BoilerPlateWeb.UserController.api_manual_upload(
           requestor,
           us_user,
           id,
           assignment.id,
           assignment.recipient_id,
           file,
           :document
         ) do
      :ok ->
        BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, assignment.recipient_id)
        text(conn, "OK")

      :forbidden ->
        conn |> put_status(400) |> json(%{error: :forbidden})

      :bad_file ->
        conn |> put_status(400) |> json(%{error: :bad_file})
    end
  end

  def recipient_missing_filerequest(conn, %{
        "assignmentId" => aid,
        "id" => id,
        "missing_reason" => missing_reason,
        "force" => force
      }) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    Logger.info(
      "missing_filerequest: assignmentId #{aid} id #{id} missing_reason #{missing_reason} force #{force}"
    )

    case BoilerPlateWeb.DocumentController.api_request_missing(
           us_user,
           aid,
           id,
           missing_reason,
           force
         ) do
      :ok ->
        # No need to invalidate the cache here as the DocumentController.api_request_missing/5 call does it already
        text(conn, "OK")

      :forbidden ->
        conn |> put_status(400) |> json(%{error: :forbidden})
    end
  end

  def recipient_upload_filerequest(conn, %{
        "id" => id,
        "file" => files,
        "recipientId" => _rid,
        "assignmentId" => aid
      }) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    assignment = Repo.get(PackageAssignment, aid)

    recipient =
      Repo.one(
        from r in Recipient,
          where:
            r.status == 0 and r.user_id == ^us_user.id and r.company_id == ^assignment.company_id,
          select: r
      )

    res =
      case BoilerPlateWeb.DocumentController.merge_multiple_file_uploads(files) do
        {:ok, file} ->
          BoilerPlateWeb.UserController.api_upload_user_request(
            us_user,
            recipient.id,
            assignment.id,
            id,
            file,
            true
          )

        _ ->
          IO.inspect("Error merging pdfs")
      end

    if res == :ok do
      BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, recipient.id)
      text(conn, "OK")
    else
      conn |> put_status(500) |> text(res)
    end
  end

  def recipient_save_filerequest(conn, %{
        "id" => id,
        "file" => files,
        "recipientId" => _rid,
        "assignmentId" => aid
      }) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    assignment = Repo.get(PackageAssignment, aid)

    recipient =
      Repo.one(
        from r in Recipient,
          where:
            r.status == 0 and r.user_id == ^us_user.id and r.company_id == ^assignment.company_id,
          select: r
      )

    {res, id, status} =
      case BoilerPlateWeb.DocumentController.merge_multiple_file_uploads(files) do
        {:ok, file} ->
          BoilerPlateWeb.UserController.api_save_user_request(
            us_user,
            recipient.id,
            assignment.id,
            id,
            file,
            true
          )

        _ ->
          IO.inspect("Error merging pdfs")
      end

    if res == :ok do
      BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, recipient.id)
      json(conn, %{res: res, id: id, isSubmitted: status == 1})
    else
      conn |> put_status(500) |> json(%{res: res, id: id})
    end
  end

  def recipient_upload_additional_requests(conn, %{
        "id" => id,
        "file" => files,
        "recipientId" => _rid,
        "assignmentId" => aid,
        "requestName" => req_name
      }) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    assignment = Repo.get(PackageAssignment, aid)

    recipient =
      Repo.one(
        from r in Recipient,
          where:
            r.status == 0 and r.user_id == ^us_user.id and r.company_id == ^assignment.company_id,
          select: r
      )

    is_mergable_files? =
      files
      |> Enum.all?(&FileHelpers.is_file_mergable_type?/1)

    res =
      if is_mergable_files? do
        case BoilerPlateWeb.DocumentController.merge_multiple_file_uploads(files) do
          {:ok, file} ->
            BoilerPlateWeb.UserController.api_upload_additional_requests(
              us_user,
              recipient.id,
              assignment.id,
              id,
              req_name,
              file
            )

          _ ->
            IO.inspect("Error merging pdfs")
            :error
        end
      else
        upload_additional_requests(us_user, req_name, id, assignment, files)
      end

    case res do
      {:ok, ereq_id} ->
        BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, recipient.id)
        json(conn, %{id: ereq_id})

      _ ->
        conn |> put_status(500) |> text(res)
    end
  end

  def upload_additional_requests(us_user, req_name, id, assignment, files) do
    # upload each files as a separate req, the first upload handles the additional uploads
    recipient =
      Repo.one(
        from r in Recipient,
          where:
            r.status == 0 and r.user_id == ^us_user.id and r.company_id == ^assignment.company_id,
          select: r
      )

    request = Repo.get(DocumentRequest, id)

    [first_upload | remaining_uploads] = files

    Repo.transaction(fn ->
      with {:ok, ereq_id} <-
             BoilerPlateWeb.UserController.api_upload_additional_requests(
               us_user,
               recipient.id,
               assignment.id,
               id,
               req_name,
               first_upload
             ) do
        Enum.each(remaining_uploads, fn file ->
          BoilerPlateWeb.UserController.create_request_and_upload_docs(
            us_user,
            recipient.id,
            assignment.id,
            request.id,
            file
          )
        end)

        ereq_id
      else
        {:error, error_key} ->
          Repo.rollback(error_key)
          nil
      end
    end)
  end

  def recipient_edit_filerequest(conn, %{
        "pid" => id,
        "file" => files
      }) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    current_freq = Repo.get(RequestCompletion, id)
    bucket = Application.get_env(:boilerplate, :s3_bucket)

    body = @storage_mod.download_file_stream(bucket, "uploads/#{current_freq.file_name}")

    file_ext = Path.extname(current_freq.file_name)
    {:ok, tmp_current_file_path} = Briefly.create(prefix: "curent_upload_file", extname: file_ext)
    File.write!(tmp_current_file_path, body)
    filename = Path.basename(tmp_current_file_path)

    current_file = %{
      path: tmp_current_file_path,
      filename: filename
    }

    all_files = [current_file] ++ files

    {res, _id, _status} =
      case BoilerPlateWeb.DocumentController.merge_multiple_file_uploads(all_files) do
        {:ok, file} ->
          BoilerPlateWeb.UserController.api_save_user_request(
            us_user,
            current_freq.recipientid,
            current_freq.assignment_id,
            current_freq.requestid,
            file,
            true
          )

        _ ->
          IO.inspect("Error merging pdfs")
      end

    if res == :ok do
      BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, current_freq.recipientid)
      text(conn, "OK")
    else
      conn |> put_status(500) |> text(res)
    end
  end

  def recipient_delete_filerequest(conn, %{"id" => id}) do
    file_request = Repo.get(RequestCompletion, id)
    Repo.update!(RequestCompletion.changeset(file_request, %{status: 8}))
    request_info = Repo.get(DocumentRequest, file_request.requestid)

    # delete task confirmation file request from contents
    if request_info.flags == 6 do
      assignment = Repo.get(PackageAssignment, file_request.assignment_id)
      contents = Repo.get(PackageContents, assignment.contents_id)

      new_requests = contents.requests |> Enum.filter(&(&1 != request_info.id))
      cs = PackageContents.changeset(contents, %{requests: new_requests})
      Repo.update!(cs)

      unset_has_upload_cs =
        DocumentRequest.changeset(
          Repo.get(DocumentRequest, file_request.file_request_reference),
          %{has_file_uploads: false}
        )

      Repo.update!(unset_has_upload_cs)
    end

    text(conn, "OK")
  end

  def recipient_submit_filerequest(conn, %{
        "id" => cid,
        "reqid" => req_id
      }) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    uploaded_req = Repo.get(RequestCompletion, cid)

    recipient =
      Repo.one(
        from r in Recipient,
          where:
            r.status == 0 and r.user_id == ^us_user.id and
              r.company_id == ^uploaded_req.company_id,
          select: r
      )

    res =
      BoilerPlateWeb.UserController.api_submit_uploaded_user_request(
        us_user,
        recipient.id,
        cid,
        req_id
      )

    if res == :ok do
      BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, recipient.id)
      text(conn, "OK")
    else
      conn |> put_status(500) |> text(res)
    end
  end

  def recipient_upload_document(conn, %{
        "id" => id,
        "assignmentId" => aid,
        "recipientId" => rid,
        "file" => files
      }) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    assignment = Repo.get(PackageAssignment, aid)
    recipient = Repo.get(Recipient, rid)

    res =
      case BoilerPlateWeb.DocumentController.merge_multiple_file_uploads(files) do
        {:ok, file} ->
          BoilerPlateWeb.UserController.api_upload_user_document(
            us_user,
            recipient.id,
            assignment.id,
            id,
            true,
            file
          )

        _ ->
          IO.inspect("Error merging pdfs")
      end

    if res == :ok do
      BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, recipient.id)
      text(conn, "OK")
    else
      conn |> put_status(500) |> text(res)
    end
  end

  def recipient_upload_multiple_files(conn, %{
        "id" => id,
        "file" => files,
        "recipientId" => _rid,
        "assignmentId" => aid
      }) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    assignment = Repo.get(PackageAssignment, aid)

    recipient =
      Repo.one(
        from r in Recipient,
          where:
            r.status == 0 and r.user_id == ^us_user.id and r.company_id == ^assignment.company_id,
          select: r
      )

    request = Repo.get(DocumentRequest, id)

    [first_upload | remaining_uploads] = files

    Repo.transaction(fn ->
      case BoilerPlateWeb.UserController.upload_recipient_request(
             us_user,
             recipient.id,
             assignment.id,
             id,
             first_upload
           ) do
        :ok ->
          Enum.each(remaining_uploads, fn file ->
            BoilerPlateWeb.UserController.create_request_and_upload_docs(
              us_user,
              recipient.id,
              assignment.id,
              request.id,
              file
            )
          end)

          BoilerPlateWeb.UserController.check_package_completion_and_send_mail(
            assignment.package_id,
            assignment,
            recipient
          )

        {:error, error_key} ->
          Repo.rollback(error_key)
      end
    end)

    BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, recipient.id)

    text(conn, "OK")
  end

  def recipient_upload_confirmation(conn, %{
        "tid" => task_req_id,
        "file" => file,
        "assignmentId" => aid
      }) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    assignment = Repo.get(PackageAssignment, aid)

    recipient =
      Repo.one(
        from r in Recipient,
          where:
            r.status == 0 and r.user_id == ^us_user.id and r.company_id == ^assignment.company_id,
          select: r
      )

    {resp, uploaded_id} =
      if recipient.id == assignment.recipient_id do
        task_request = Repo.get(DocumentRequest, task_req_id)

        req =
          BoilerPlateWeb.DocumentController.clone_request(task_request, %{
            "attr" => [],
            "flags" => 6,
            "status" => 0
          })

        {_res, uploaded_id, _status} =
          BoilerPlateWeb.UserController.api_save_user_request(
            us_user,
            recipient.id,
            assignment.id,
            req.id,
            file,
            true
          )

        # update package content
        contents = Repo.get(PackageContents, assignment.contents_id)
        new_requests = contents.requests ++ [req.id]

        cs = PackageContents.changeset(contents, %{requests: new_requests})
        Repo.update!(cs)

        # add task req reference to uploaded doc
        uploaded_req_cs =
          RequestCompletion.changeset(Repo.get(RequestCompletion, uploaded_id), %{
            file_request_reference: task_req_id
          })

        Repo.update!(uploaded_req_cs)

        # set flag to true to identify if the task has confirmation file uploads
        has_upload_cs = DocumentRequest.changeset(task_request, %{has_file_uploads: true})
        Repo.update!(has_upload_cs)

        {:ok, uploaded_id}
      else
        conn |> put_status(403) |> text(:forbidden)
      end

    if resp == :ok do
      BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, recipient.id)
      json(conn, %{id: uploaded_id})
    else
      conn |> put_status(500) |> text(resp)
    end
  end

  def recipient_edit_checklist(
        conn,
        %{"id" => contents_id, "checklist_name" => contents_title}
      ) do
    contents = Repo.get(PackageContents, contents_id)
    recipient = get_current_recipient(conn)

    if recipient.id == contents.recipient_id do
      Repo.update(PackageContents.changeset(contents, %{title: contents_title}))
      text(conn, "OK")
    else
      conn |> put_status(403) |> text(:forbidden)
    end
  end

  defp make_recipient(recp) do
    us = Repo.get(User, recp.user_id)

    %{
      id: recp.id,
      name: recp.name,
      email: us.email,
      added: recp.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
      last_modified: recp.updated_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
      company: recp.organization,
      phone_number: recp.phone_number,
      show_in_dashboard: recp.show_in_dashboard,
      is_deleted: recp.status == 1,
      email_editable: BoilerPlateWeb.RecipientController.recipient_email_editable(recp),
      start_date:
        if(recp.start_date != nil,
          do: recp.start_date |> Timex.format!("{YYYY}-{0M}-{0D}"),
          else: ""
        ),
      user_id: recp.user_id
    }
  end

  def make_cabinet_of(recipient, company) do
    Repo.all(
      from c in Cabinet,
        where: c.company_id == ^company.id and c.recipient_id == ^recipient.id and c.status == 0,
        select: c
    )
    |> Enum.map(
      &%{
        id: &1.id,
        name: &1.name,
        file_name: &1.filename,
        description: "",
        # Manually added
        status: %{
          status: 4,
          date: &1.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
          type: :manually_added
        },
        inserted_at: &1.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D}")
      }
    )
  end

  defp make_customizations(contents) do
    Repo.all(
      from r in RawDocumentCustomized,
        where:
          r.contents_id == ^contents.id and r.recipient_id == ^contents.recipient_id and
            r.status == 0,
        order_by: [asc: r.inserted_at],
        select: r
    )
    |> Enum.map(fn x ->
      iac_doc = IACDocument.get_for(:raw_document_customized, x)

      %{
        x.raw_document_id => %{
          customization_id: x.id,
          document_id: x.raw_document_id,
          contents_id: x.contents_id,
          is_iac: IACDocument.setup?(iac_doc),
          iac_doc_id:
            if iac_doc != nil do
              iac_doc.id
            else
              0
            end,
          file_name: x.file_name
        }
      }
    end)
    # Hotfix: gets rsdc in asc order and while merge gets recent replaced iac docs
    |> Enum.reduce(%{}, fn x, acc -> Map.merge(acc, x) end)
  end

  defp has_contents_specific_extra_file_uploads?(ids) do
    query =
      from r in DocumentRequest,
        where: r.id in ^ids and r.flags == 4 and r.status == 0,
        select: r

    ids_count = Repo.aggregate(query, :count, :id)

    if ids_count == 1 do
      true
    else
      false
    end
  end

  defp make_contents(contents, recipient) do
    tags = Repo.all(from r in RecipientTag, where: r.id in ^contents.tags, select: r)
    %{
      id: contents.id,
      documents: Enum.map(contents.documents, &make_doc_from_id/1),
      customizations: make_customizations(contents),
      title: contents.title,
      description: contents.description,
      recipient: make_recipient(recipient),
      inserted_at: contents.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
      updated_at: contents.updated_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
      enforce_due_date: contents.enforce_due_date,
      due_days: contents.due_days,
      requests:
        contents.requests
        |> Enum.map(&Repo.get(DocumentRequest, &1))
        |> Enum.map(
          &%{
            name: &1.title,
            description: &1.description,
            type:
              if 2 in &1.attributes do
                "data"
              else
                if 1 in &1.attributes do
                  "task"
                else
                  "file"
                end
              end,
            new: false,
            id: &1.id,
            flags: &1.flags,
            link: &1.link,
            dashboard_order: &1.dashboard_order,
            is_confirmation_required: &1.is_confirmation_required
          }
        )
        |> Enum.sort_by(& &1.dashboard_order),
      allowed_additional_files_uploads:
        has_contents_specific_extra_file_uploads?(contents.requests),
      forms: FormController.get_forms_for_contents(contents.id),
      ses_struct: BoilerPlateWeb.IACController.ses_get_struct(:contents, contents.id),
      tags: BoilerPlateWeb.DocumentTagView.render("recipient_tags.json", recipient_tags: tags)
    }
  end

  def requestor_get_contents_by_id(conn, %{"id" => id}) do
    contents = Repo.get(PackageContents, id)
    requestor = get_current_requestor(conn)

    cond do
      requestor == nil ->
        conn |> put_status(403) |> text("forbidden")

      contents == nil ->
        conn |> put_status(404) |> text("Not Found")

      true ->
        recipient = Repo.get(Recipient, contents.recipient_id)

        if recipient.company_id != requestor.company_id do
          conn |> put_status(403) |> text("forbidden")
        else
          json(conn, make_contents(contents, recipient))
        end
    end
  end

  def requestor_get_contents(conn, %{"pid" => pid, "rid" => rid}) do
    recipient = Repo.get(Recipient, rid)
    base_package = Repo.get(Package, pid)

    contents = PackageContents.get_if_exists(recipient, base_package)

    if contents == nil do
      conn |> put_status(404) |> text("Not Found")
    else
      res =
        make_contents(contents, recipient)
        |> Map.put_new("allow_mutiple_requests", base_package.allow_multiple_requests)

      json(conn, res)
    end
  end

  def requestor_reset_customize_document(conn, %{
        "contentsId" => contentsId,
        "templateId" => templateId
      }) do
    contents = Repo.get(PackageContents, contentsId)
    recipient = Repo.get(Recipient, contents.recipient_id)
    company = Repo.get(Company, recipient.company_id)
    rd = Repo.get(RawDocument, templateId)

    # Mark all RSDCs stale
    rsdcs =
      Repo.all(
        from r in RawDocumentCustomized,
          where:
            r.status == 0 and r.contents_id == ^contentsId and r.recipient_id == ^recipient.id and
              r.raw_document_id == ^templateId,
          select: r
      )

    for rsdc <- rsdcs do
      cs = RawDocumentCustomized.changeset(rsdc, %{status: 1})

      Repo.update!(cs)
    end

    # Is there an IACDocument for the RD?
    iac_doc = IACDocument.get_for(:raw_document, rd)

    if iac_doc != nil do
      # Find any IAFs and mark them as stale
      iaf =
        BoilerPlateWeb.IACController.get_iaf_for(
          recipient,
          company,
          iac_doc,
          contents,
          Repo.get(IACMasterForm, iac_doc.master_form_id)
        )

      cs = IACAssignedForm.changeset(iaf, %{status: 1})
      Repo.update!(cs)
    end

    text(conn, "OK")
  end

  def requestor_customize_document(conn, %{
        "id" => contentsId,
        "documentId" => documentId,
        "file" => file
      }) do
    template_fn = UUID.uuid4() <> Path.extname(file.filename)
    rd = Repo.get(RawDocument, documentId)
    contents = Repo.get(PackageContents, contentsId)
    recipient = Repo.get(Recipient, contents.recipient_id)

    # Store the RSDC
    {_status, final_path} =
      RawDocumentCustomized.store(%{
        filename: template_fn,
        path: file.path
      })

    rdc = %RawDocumentCustomized{
      raw_document_id: rd.id,
      contents_id: contents.id,
      recipient_id: recipient.id,
      file_name: final_path,
      status: 0,
      flags: 0
    }

    Repo.insert!(rdc)

    text(conn, "OK")
  end

  def requestor_new_contents(conn, %{"packageId" => pid, "recipientId" => rid}) do
    recipient = Repo.get(Recipient, rid)
    base_package = Repo.get(Package, pid)

    if recipient.status == 1 do
      changeset = %{
        status: 0
      }

      cs = Recipient.changeset(recipient, changeset)
      Repo.update!(cs)
    end

    contents = PackageContents.inprogress_package(recipient, base_package)

    json(conn, make_contents(contents, recipient))
  end

  defp assignment_params(pkg_id, content_id, recipient_id, company_id, requestor_id) do
    content = Repo.get(PackageContents, content_id)
    due_date = get_assignment_due_date(content)

    enforce_due_date =
      if due_date != nil do
        content.enforce_due_date
      else
        nil
      end

    %{
      package_id: pkg_id,
      recipient_id: recipient_id,
      requestor_id: requestor_id,
      company_id: company_id,
      contents_id: content_id,
      open_status: 0,
      due_date: due_date,
      enforce_due_date: enforce_due_date,
      append_note: "",
      docs_downloaded: [],
      # recipient created checklist
      flags: 5,
      status: 0
    }
  end

  defp get_iac_assigned_form(original_contents_id, recipient_id) do
    iafs =
      Repo.all(
        from iaf in IACAssignedForm,
          where: iaf.contents_id == ^original_contents_id and iaf.recipient_id == ^recipient_id,
          select: iaf
      )

    if iafs != nil do
      iac_assigned_form =
        iafs
        |> Enum.map(fn x -> Map.delete(x, :id) end)
        |> Enum.map(fn x -> Map.delete(x, :inserted_at) end)
        |> Enum.map(fn x -> Map.delete(x, :updated_at) end)
        |> Enum.map(fn x -> Map.delete(x, :__meta__) end)
        |> Enum.map(fn x -> Map.delete(x, :__struct__) end)

      {:ok, iac_assigned_form}
    end
  end

  defp clone_iac_fields_and_get_ids(iac_assigned_form) do
    iac_fields =
      Repo.all(
        from field in IACField,
          where: field.id in ^iac_assigned_form.fields,
          select: field
      )

    requestor_filled_field_ids =
      Enum.filter(iac_fields, &(&1.fill_type == 1 or &1.fill_type == 0))
      |> Enum.map(& &1.id)

    requestor_assigned_fields =
      Enum.filter(iac_fields, &(&1.fill_type != 1 and &1.fill_type != 0))
      |> Enum.map(fn x -> Map.delete(x, :id) end)
      |> Enum.map(fn x -> Map.delete(x, :__meta__) end)
      |> Enum.map(fn x -> Map.delete(x, :__struct__) end)
      # reset the assigned field values
      |> Enum.map(fn iac_ -> %{iac_ | default_value: "", set_value: "", flags: 5} end)

    requestor_assigned_field_ids =
      Enum.map(requestor_assigned_fields, fn x ->
        Repo.insert!(IACField.changeset(%IACField{}, x))
      end)
      |> Enum.map(& &1.id)

    field_ids = requestor_assigned_field_ids ++ requestor_filled_field_ids
    # update IAF with new fields
    %{iac_assigned_form | fields: field_ids}
  end

  defp clone_iac_assigned_form(iaf) do
    Repo.insert!(IACAssignedForm.changeset(%IACAssignedForm{}, iaf))
    :ok
  end

  defp prepare_and_clone_iac_assigned_form(original_contents_id, rid, contents_id) do
    with {:ok, iac_assigned_form} <- get_iac_assigned_form(original_contents_id, rid) do
      iac_assigned_form
      |> Enum.map(&clone_iac_fields_and_get_ids/1)
      |> Enum.map(fn iaf -> %{iaf | contents_id: contents_id, flags: 5} end)
      |> Enum.each(&clone_iac_assigned_form/1)

      {:ok}
    end
  end

  def recipient_new_assignments(conn, %{
        "packageId" => _pid,
        "requestorId" => rid,
        "contentsId" => original_contents_id,
        "recipientDescription" => rdesc,
        "assignmentId" => original_assignment_id,
        "docRequests" => documents_requests
      }) do
    assignment = Repo.get(PackageAssignment, original_assignment_id)

    requestor =
      Repo.one(
        from r in Requestor,
          where: r.status == 0 and r.user_id == ^rid and r.company_id == ^assignment.company_id,
          select: r
      )

    company = Repo.get(Company, requestor.company_id)
    recipient = get_current_recipient(conn)
    original_contents = Repo.get(PackageContents, original_contents_id)

    Repo.transaction(fn ->
      with {:ok, contents} <-
             PackageContents.duplicate_package_contents(recipient, original_contents),
           {:ok, _content_updated} <-
             Repo.update(
               PackageContents.changeset(contents, %{recipient_description: "#{rdesc}"})
             ),
           {:ok, _pkg_created} <-
             Repo.insert(
               PackageAssignment.changeset(
                 %PackageAssignment{},
                 assignment_params(
                   assignment.package_id,
                   contents.id,
                   recipient.id,
                   company.id,
                   requestor.id
                 )
               )
             ),
           {:ok} <-
             prepare_and_clone_iac_assigned_form(original_contents_id, recipient.id, contents.id) do
        for doc <- documents_requests do
          if doc["is_rspec"] == true and doc["is_iac"] == true do
            iac_doc = Repo.get(IACDocument, doc["iac_document_id"])
            customization = doc["customization"]
            id = customization["customization_id"]

            rdc_ =
              Repo.get(RawDocumentCustomized, id)
              |> Map.delete(:id)
              |> Map.delete(:__meta__)
              |> Map.delete(:__struct__)
              |> Map.delete(:inserted_at)
              |> Map.delete(:updated_at)

            rdc_attr = %{rdc_ | flags: 5, recipient_id: recipient.id, contents_id: contents.id}

            rsdc =
              Repo.insert(RawDocumentCustomized.changeset(%RawDocumentCustomized{}, rdc_attr))
              |> elem(1)

            IACDocument.clone_into(iac_doc, :raw_document_customized, rsdc)
          else
            nil
            # do nothing
          end
        end
      else
        {:error, error_key} -> Repo.rollback(error_key)
      end
    end)

    text(conn, "OK")
  end

  def requestor_put_contents(conn, params) do
    base_contents = Repo.get(PackageContents, params["id"])
    forms = params["forms"] || []

    incoming_contents = %{
      documents: params["documents"],
      requests: params["requests"],
      title: params["title"],
      description: params["description"],
      forms: forms
    }

    cs = PackageContents.changeset(base_contents, incoming_contents)
    Repo.update!(cs)
    # requestor dashboard unsend documents api
    BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, base_contents.recipient_id)

    text(conn, "OK")
  end

  def requestor_delete_contents(conn, %{"id" => contents_id}) do
    draft_contents = Repo.get(PackageContents, contents_id)

    if draft_contents.status == 2 do
      # Repo.delete!(draft_contents)
      Repo.update!(
        PackageContents.changeset(draft_contents, %{
          recipient_id: 0
        })
      )

      # set invalid recipeint id instead of delete
    else
      conn |> put_status(403) |> text(:forbidden)
    end

    text(conn, "OK")
  end

  def requestor_delete_complete_item(
        conn,
        %{
          "id" => id,
          "assignment_id" => assignment_id,
          "completion_id" => completion_id,
          "type" => type
        }
      ) do
    requestor = get_current_requestor(conn)

    assignment = Repo.get(PackageAssignment, assignment_id)

    if assignment.company_id == requestor.company_id do
      doc = %{
        id: id,
        completion_id: completion_id
      }

      case type do
        "request" -> :request |> handle_delete_completed_item(conn, doc, assignment)
        "document" -> :document |> handle_delete_completed_item(conn, doc, assignment)
        _ -> conn |> put_status(400) |> json(%{msg: "Invalid Item Type"})
      end
    else
      conn |> put_status(401) |> json(%{msg: "Unauthorized"})
    end
  end

  def handle_delete_completed_item(:request, conn, doc, assignment) do
    # pass retention time as 0, because in the end it doesn't even matter.
    doc |> FileCleanerUtils.delete_request(assignment.id, 0, true)
    BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, assignment.recipient_id)
    conn |> json(%{msg: "OK", type: "request"})
  end

  def handle_delete_completed_item(:document, conn, doc, assignment) do
    # pass retention time as 0, because in the end it doesn't even matter.
    doc |> FileCleanerUtils.delete_document(assignment.id, 0, true)
    BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, assignment.recipient_id)
    conn |> json(%{msg: "OK", type: "document"})
  end

  def make_document_request(req) do
    %{
      id: req.id,
      name: req.title,
      description: req.description,
      inserted_at: req.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
      type:
        if 2 in req.attributes do
          "data"
        else
          if 1 in req.attributes do
            "task"
          else
            "file"
          end
        end,
      new: false,
      flags: req.flags,
      link: req.link,
      dashboard_order: req.dashboard_order,
      allow_expiration_tracking: req.enable_expiration_tracking,
      is_confirmation_required: req.is_confirmation_required
    }
  end

  defp get_assignment_due_date(contents) do
    if contents.enforce_due_date != nil and contents.enforce_due_date and contents.due_days != nil do
      # db server timezone
      utc_today = BoilerPlate.CustomDateTimex.get_datetime()
      BoilerPlate.CustomDateTimex.subtract_dates(:day, utc_today, contents.due_days)
    else
      nil
    end
  end

  def requestor_new_assignment(conn, params) do
    enforce_due_date = params["enforceDueDate"]
    due_days = params["dueDays"]
    contents_id = params["contentsId"]
    append_note = params["append_note"]

    assignment_query =
      from pa in PackageAssignment, where: pa.contents_id == ^contents_id, select: pa

    assignment_exists? = Repo.aggregate(assignment_query, :count, :id) > 0

    if not assignment_exists? do
      requestor = get_current_requestor(conn)

      company = Repo.get(Company, requestor.company_id)
      saved_contents = Repo.get(PackageContents, params["contentsId"])

      contents =
        Repo.update!(
          PackageContents.changeset(saved_contents, %{
            enforce_due_date: enforce_due_date,
            due_days: due_days
          })
        )

      checklist_identifier = params["checklistIdentifier"]
      base_pkg = Repo.get(Package, contents.package_id)

      # append_note = contents.append_note
      enforce_due_date = contents.enforce_due_date
      due_date = get_assignment_due_date(contents)

      assign = %PackageAssignment{
        package_id: base_pkg.id,
        recipient_id: contents.recipient_id,
        requestor_id: requestor.id,
        company_id: company.id,
        contents_id: contents.id,
        open_status: 0,
        due_date: due_date,
        enforce_due_date: enforce_due_date,
        append_note: append_note,
        docs_downloaded: [],
        flags: 0,
        status: 0
      }

      Repo.update!(
        PackageContents.changeset(contents, %{
          status: 0,
          req_checklist_identifier: "#{checklist_identifier}"
        })
      )

      assign = Repo.insert!(assign)
      BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, contents.recipient_id)

      # Append Note
      if assign != nil do
        recip = Repo.get(Recipient, contents.recipient_id)
        user = Repo.get(User, recip.user_id)
        contents = contents |> Map.put(:due_date, assign.due_date)

        Email.send_assigned_email(
          user,
          recip,
          contents,
          company,
          BoilerPlate.Guardian.Plug.current_resource(conn),
          assign,
          append_note
        )
      else
        conn |> put_status(400) |> json(%{error: :assignment_email_fail})
      end
    end

    text(conn, "OK")
  end

  def requestor_commit_rsds(conn, %{"id" => id, "documentIds" => documentIds}) do
    contents = Repo.get(PackageContents, id)

    for did <- documentIds do
      doc = Repo.get(RawDocument, did)

      rdc = %RawDocumentCustomized{
        raw_document_id: doc.id,
        contents_id: contents.id,
        recipient_id: contents.recipient_id,
        file_name: doc.file_name,
        status: 0,
        flags: 1
      }

      nrdc = Repo.insert!(rdc)

      iac_doc = IACDocument.get_for(:raw_document, doc)

      if IACDocument.setup?(iac_doc) do
        IACDocument.clone_into(iac_doc, :raw_document_customized, nrdc)
      end
    end

    text(conn, "OK")
  end

  def requestor_new_document_request(
        conn,
        params = %{
          "name" => name,
          "type" => type,
          "file_retention_period" => file_retention_period
        }
      ) do
    attrs =
      case type do
        "file" -> []
        "allow_extra_files" -> []
        "task" -> [1]
        "data" -> [2]
      end

    flags =
      case type do
        "allow_extra_files" -> 4
        _ -> 0
      end

    link = params["link"]

    req = %DocumentRequest{
      packageid: 0,
      title: name,
      description: params["description"],
      attributes: attrs,
      status: 0,
      flags: flags,
      link: link,
      file_retention_period: file_retention_period,
      is_confirmation_required: params["is_confirmation_required"] || false
    }

    render(conn, "document_request.json", document_request: Repo.insert!(req))
  end

  #  TODO remove soon
  defp requests_in(pkg) do
    Repo.all(
      from r in DocumentRequest, where: r.packageid == ^pkg.id and r.status == 0, select: r
    )
    |> Enum.sort_by(& &1.dashboard_order)
  end

  defp make_doc_from_id(docid) do
    doc = Repo.get(RawDocument, docid)
    iac_doc = IACDocument.get_for(:raw_document, doc)

    tags =
      if doc.tags != nil do
        all_tags = Repo.all(from r in DocumentTag, where: r.id in ^doc.tags, select: r)

        %{
          id: doc.tags,
          values: all_tags |> Enum.map(&%{id: &1.id, name: &1.name, flags: &1.sensitive_level})
        }
      else
        []
      end

    %{
      id: doc.id,
      name: doc.name,
      description: doc.description,
      company_id: doc.company_id,
      file_name: doc.file_name,
      is_iac: iac_doc != nil,
      iac_doc_id:
        if iac_doc == nil do
          0
        else
          iac_doc.id
        end,
      is_rspec: RawDocument.is_rspec?(doc),
      is_info: RawDocument.is_info?(doc),
      allow_edits: doc.editable_during_review,
      inserted_at: doc.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
      inserted_time: doc.inserted_at |> Timex.format!("{0h12}:{0m}:{0s} {AM}"),
      updated_at: doc.updated_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
      updated_time: doc.updated_at |> Timex.format!("{0h12}:{0m}:{0s} {AM}"),
      type: doc.type,
      tags: tags
    }
  end

  def requestor_checklists(conn, _params) do
    requestor = get_current_requestor(conn)

    company = Repo.get(Company, requestor.company_id)

    data =
      Package.all_of(company)
      |> Enum.filter(&(&1.is_archived == false))
      |> Enum.sort_by(&String.downcase(&1.title), :asc)

    render(conn, "packages.json", packages: data)
  end

  def requestor_checklist_with_id(conn, %{"id" => id}) do
    requestor = get_current_requestor(conn)

    pkg = Repo.get(Package, id)

    if pkg.company_id != requestor.company_id do
      conn |> put_status(403) |> text("forbidden")
    else
      render(conn, "package.json", package: pkg)
    end
  end

  def requestor_delete_checklist(conn, %{"id" => id}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    reply = BoilerPlateWeb.PackageController.api_delete_package(us_user, id)

    if reply == :ok do
      text(conn, "OK")
    else
      conn |> put_status(400) |> json(%{error: reply})
    end
  end

  # Requestor Update Checklist
  def requestor_put_checklist(conn, params) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    requestor = get_current_requestor(conn)

    company = Repo.get(Company, requestor.company_id)

    # file_requests are processed separately
    incoming_pkg = %{
      id: params["id"],
      title: params["name"],
      templates: params["documents"],
      description: params["description"],
      allow_duplicate_submission: params["allow_duplicate_submission"],
      allow_multiple_requests: params["allow_multiple_requests"],
      forms: params["forms"],
      enforce_due_date: params["enforce_due_date"],
      due_days: params["due_days"],
      due_date_type: params["due_date_type"],
      status:
        if params["commit"] == true do
          0
        else
          4
        end,
      tags: params["tags"] || []
    }

    file_requests = params["file_requests"]

    base_pkg = Repo.get(Package, incoming_pkg.id)
    cs = Package.changeset(base_pkg, incoming_pkg |> Map.drop([:id]))
    Repo.update!(cs)

    ses_struct = params["ses_struct"] || %{allow: false, sesTargetId: []}
    # setup IAC/SES if requested
    if ses_struct["allow"] do
      checklist_id = base_pkg.id
      raw_docs = ses_struct["sesTargetId"]

      case BoilerPlateWeb.IACController.create_or_update_ses_exportable(
             checklist_id,
             raw_docs,
             company
           ) do
        {:ok, _} -> :ok
        {:error, msg} -> raise ArgumentError, message: msg
      end
    end

    # Now process the file requests
    # Get the current file requests in the package
    base_requests = requests_in(base_pkg)
    base_ids = base_requests |> Enum.map(& &1.id)

    seen_ids =
      for fr <- file_requests do
        if fr["new"] == false do
          # record that we saw this, so later we can compare to find the deleted ones
          base_file = Repo.get(DocumentRequest, fr["id"])
          allow_expiration_tracking = fr["allow_expiration_tracking"] || false

          cs =
            DocumentRequest.changeset(base_file, %{
              title: fr["name"],
              description: fr["description"],
              link: fr["link"] || %{},
              dashboard_order: fr["order"],
              enable_expiration_tracking: allow_expiration_tracking,
              is_confirmation_required: fr["is_confirmation_required"] || false
            })

          Repo.update!(cs)
          fr["id"]
        else
          # Create the file request, this is where File Request is only file...
          # FIXME: an error here should be propagated upwards!
          BoilerPlateWeb.PackageController.api_add_request(us_user, fr, base_pkg.id)

          0
        end
      end

    seen_ids = seen_ids |> Enum.filter(&(&1 != 0))

    for i <- base_ids do
      if i not in seen_ids do
        # We haven't seen this ID, so mark this request as deleted
        BoilerPlateWeb.PackageController.api_delete_request(us_user, i, base_pkg.id)
      end
    end

    incoming_pkg.forms |> FormController.add_forms_in_package(incoming_pkg.id)

    text(conn, "OK")
  end

  def requestor_archive_checklist(conn, params) do
    requestor = get_current_requestor(conn)
    base_checklist = Repo.get(Package, params["id"])

    if requestor == nil or base_checklist == nil or
         base_checklist.company_id != requestor.company_id do
      conn |> put_status(403) |> text("Forbidden")
    else
      checklist_archive_changeset = %{is_archived: not base_checklist.is_archived}

      cs = Package.changeset(base_checklist, checklist_archive_changeset)
      Repo.update!(cs)

      text(conn, "OK")
    end
  end

  def make_requestor_package(
        pkg_name,
        pkg_description,
        us_user,
        pkg_template_list,
        company_id,
        is_archived,
        allow_duplicate_submission
      ) do
    pkg =
      Repo.insert!(%Package{
        title: pkg_name,
        description: pkg_description,
        company_id: company_id,
        templates: pkg_template_list,
        status: 0,
        is_archived: is_archived,
        allow_duplicate_submission: allow_duplicate_submission
      })

    request_data = %{
      "name" => "PlaceHolder for Recipient File Uploads",
      "description" => "",
      "type" => "allow_extra_files"
    }

    res = BoilerPlateWeb.PackageController.api_add_request(us_user, request_data, pkg.id)

    if res == :ok do
      {:ok, pkg.id}
    else
      {:error}
    end
  end

  def requestor_new_checklist(conn, %{"intakeLink" => true, "checklistId" => id}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    requestor = get_current_requestor(conn)

    case BoilerPlateWeb.PackageController.api_make_adhoc_link_package(requestor, us_user, id) do
      {:ok, link} -> json(conn, %{link: link})
      reply -> conn |> put_status(400) |> json(%{error: reply})
    end
  end

  def requestor_new_checklist(conn, %{"secureLink" => true}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    requestor = get_current_requestor(conn)

    pkg_name = "Secure File Submission"
    pkg_description = "File submission"

    {:ok, id} =
      make_requestor_package(
        pkg_name,
        pkg_description,
        us_user,
        [],
        requestor.company_id,
        true,
        true
      )

    case BoilerPlateWeb.PackageController.api_make_adhoc_link_package(requestor, us_user, id) do
      {:ok, link} -> json(conn, %{link: link})
      reply -> conn |> put_status(400) |> json(%{error: reply})
    end
  end

  def requestor_new_checklist(conn, %{"duplicate" => true, "checklistId" => id}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    requestor = get_current_requestor(conn)

    {reply, aux} =
      if requestor != nil do
        BoilerPlateWeb.PackageController.api_duplicate_package(requestor, us_user, id)
      else
        {:forbidden, 0}
      end

    if reply == :ok do
      conn |> json(%{new_id: aux})
    else
      conn |> put_status(400) |> json(%{error: reply})
    end
  end

  def requestor_new_checklist(
        conn,
        params = %{
          "name" => pkg_name,
          "description" => pkg_description,
          "documents" => pkg_template_list,
          "file_requests" => pkg_file_requests,
          "commit" => commit,
          "allow_duplicate_submission" => allow_duplicate_submission,
          "allow_multiple_requests" => allow_multiple_requests
        }
      ) do
    # If we don't commit, mark the status as "in progress"
    new_status =
      if commit do
        0
      else
        4
      end

    forms = params["forms"] || []
    ses_struct = params["ses_struct"] || %{allow: false, sesTargetId: 0}

    requestor = get_current_requestor(conn)

    company = Repo.get(Company, requestor.company_id)
    archive_checklist = params["archive_checklist"] || false
    enforce_due_date = params["enforce_due_date"] || false
    due_date_type = params["due_date_type"]
    tags = params["tags"] || []

    due_days = params["due_days"] || nil

    # TODO verify that the template IDs are sound
    pkg =
      Repo.insert!(%Package{
        title: pkg_name,
        description: pkg_description,
        company_id: company.id,
        templates: pkg_template_list,
        status: new_status,
        allow_duplicate_submission: allow_duplicate_submission,
        allow_multiple_requests: allow_multiple_requests,
        is_archived: archive_checklist,
        enforce_due_date: enforce_due_date,
        due_date_type: due_date_type,
        due_days: due_days,
        tags: tags
      })

    # setup IAC/SES if requested
    if ses_struct["allow"] do
      checklist_id = pkg.id
      raw_docs = ses_struct["sesTargetId"]

      case BoilerPlateWeb.IACController.create_or_update_ses_exportable(
             checklist_id,
             raw_docs,
             company
           ) do
        {:ok, _} -> :ok
        {:error, msg} -> raise ArgumentError, message: msg
      end
    end

    for i <- pkg_file_requests do
      type = i["type"]

      attrs =
        if type == "file" or type == "allow_extra_files" do
          []
        else
          if type == "task" do
            # task
            [1]
          else
            # data
            [2]
          end
        end

      flags =
        if type == "allow_extra_files" do
          4
        else
          0
        end

      link = i["link"] || %{}
      allow_expiration_tracking = i["allow_expiration_tracking"] || false

      new_req = %{
        packageid: pkg.id,
        title: i["name"],
        description: i["description"] || "",
        status: 0,
        flags: flags,
        attributes: attrs,
        link: link,
        dashboard_order: i["order"],
        enable_expiration_tracking: allow_expiration_tracking,
        file_retention_period: i["file_retention_period"],
        is_confirmation_required: i["is_confirmation_required"] || false
      }

      docreq_cs = DocumentRequest.changeset(%DocumentRequest{}, new_req)
      Repo.insert!(docreq_cs)
    end

    # IO.inspect(forms)

    forms |> FormController.add_forms_in_package(pkg.id)

    # Done
    BoilerPlate.Webhook.fire("checklist.create", company.id, %{
      checklist: %{
        name: pkg_name,
        description: pkg_description
      }
    })

    json(conn, %{status: :ok, id: pkg.id})
  end

  def requestor_filerequest_with_id(conn, %{"id" => id}) do
    req = Repo.get(DocumentRequest, id)

    json(conn, %{
      id: req.id,
      name: req.title
    })
  end

  defp is_info_template_viewed?(raw_doc_id, assignment_id) do
    query =
      from doc in Document,
        where:
          doc.raw_document_id == ^raw_doc_id and doc.assignment_id == ^assignment_id and
            (doc.status == 2 or doc.status == 4),
        select: doc

    Repo.exists?(query)
  end

  def requestor_read_info(conn, %{"templateId" => id, "assignmentId" => aid}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    assignment = Repo.get(PackageAssignment, aid)
    recipient = Repo.get(Recipient, assignment.recipient_id)
    rd = Repo.get(RawDocument, id)

    is_info_read? = is_info_template_viewed?(rd.id, assignment.id)

    if is_info_read? do
      conn |> put_status(200) |> text("Info already read")
    else
      res =
        BoilerPlateWeb.UserController.api_upload_user_document(
          us_user,
          recipient.id,
          assignment.id,
          id,
          false,
          rd.file_name
        )

      if res == :ok do
        BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, recipient.id)
        text(conn, "OK")
      else
        conn |> put_status(500) |> text(res)
      end
    end
  end

  defp store_new_template(
         upl,
         name,
         description,
         company_id,
         is_archived,
         template_flag,
         type \\ 0,
         tags
       ) do
    template_fn = UUID.uuid4() <> Path.extname(upl.filename)

    {_status, final_path} =
      RawDocument.store(%{
        filename: template_fn,
        path: upl.path
      })

    template = %RawDocument{
      name: name,
      # TODO should also disapper
      description: description,
      file_name: final_path,
      type: type,
      flags: template_flag,
      company_id: company_id,
      is_archived: is_archived,
      tags: tags
    }

    Repo.insert!(template)
  end

  def requestor_new_template(conn, params = %{"name" => name, "upload" => upl}) do
    is_archived = params["archive_template"] == "true"
    tags = params["tags"] || []

    requestor = get_current_requestor(conn)

    company = Repo.get(Company, requestor.company_id)

    type = RawDocument.file_extension_type(Path.extname(upl.filename))
    reply = store_new_template(upl, name, "-", company.id, is_archived, 0, type, tags)

    json(conn, %{
      id: reply.id
    })
  end

  defp package_assigned_confirmation_email(recipient, us_user, company, contents, assign) do
    recipient_user = Repo.get(User, recipient.user_id)
    Email.send_assigned_email(recipient_user, recipient, contents, company, us_user, assign)
  end

  def direct_send_templates(conn, %{
        "id" => recipient_id,
        "name" => name,
        "description" => description,
        "uploads" => upls
      }) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    requestor = get_current_requestor(conn)

    company = Repo.get(Company, requestor.company_id)
    recipient = Repo.get(Recipient, recipient_id)

    if recipient.status == 1 do
      changeset = %{
        status: 0
      }

      cs = Recipient.changeset(recipient, changeset)
      Repo.update!(cs)
    end

    Repo.transaction(fn ->
      with template_ids <-
             upls
             |> Enum.map(fn upl ->
               name = Path.basename(upl.filename, Path.extname(upl.filename))
               store_new_template(upl, name, description, company.id, true, 8, [])
             end)
             |> Enum.map(& &1.id),
           {:ok, base_pkg} <-
             Repo.insert(%Package{
               title: name,
               description: description,
               company_id: company.id,
               templates: template_ids,
               status: 0,
               is_archived: true
             }),
           {:ok, contents} <- PackageContents.create_package_contents(recipient, base_pkg),
           {:ok, assignment} <-
             Repo.insert(
               PackageAssignment.changeset(
                 %PackageAssignment{},
                 assignment_params(
                   base_pkg.id,
                   contents.id,
                   recipient.id,
                   company.id,
                   requestor.id
                 )
               )
             ) do
        # send email
        package_assigned_confirmation_email(recipient, us_user, company, contents, assignment)
      else
        {:error, error_key} -> Repo.rollback(error_key)
      end
    end)

    text(conn, "OK")
  end

  def direct_send_templates(conn, %{"id" => recipient_id, "rawDocId" => raw_doc_id}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    requestor = get_current_requestor(conn)

    company = Repo.get(Company, requestor.company_id)
    recipient = Repo.get(Recipient, recipient_id)

    raw_document = Repo.get(RawDocument, raw_doc_id)

    if recipient.company_id != raw_document.company_id or recipient.company_id != company.id do
      conn |> put_status(403) |> text(:forbidden)
    else
      cs = RawDocument.changeset(raw_document, %{flags: 8})
      Repo.update!(cs)

      Repo.transaction(fn ->
        with {:ok, base_pkg} <-
               Repo.insert(%Package{
                 title: raw_document.name,
                 description: raw_document.description,
                 company_id: company.id,
                 templates: [raw_document.id],
                 status: 0,
                 is_archived: true
               }),
             {:ok, contents} <- PackageContents.create_package_contents(recipient, base_pkg),
             {:ok, assignment} <-
               Repo.insert(
                 PackageAssignment.changeset(
                   %PackageAssignment{},
                   assignment_params(
                     base_pkg.id,
                     contents.id,
                     recipient.id,
                     company.id,
                     requestor.id
                   )
                 )
               ) do
          # Send Email
          package_assigned_confirmation_email(recipient, us_user, company, contents, assignment)
        else
          {:error, error_key} -> Repo.rollback(error_key)
        end
      end)
    end

    text(conn, "OK")
  end

  def direct_send_checklist(conn, %{"rid" => recipient_id, "cid" => id}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    requestor = get_current_requestor(conn)

    company = Repo.get(Company, requestor.company_id)
    recipient = Repo.get(Recipient, recipient_id)
    base_pkg = Repo.get(Package, id)

    if recipient.company_id != base_pkg.company_id or recipient.company_id != company.id do
      conn |> put_status(403) |> text(:forbidden)
    else
      if recipient.status == 1 do
        changeset = %{
          status: 0
        }

        cs = Recipient.changeset(recipient, changeset)
        Repo.update!(cs)
      end

      Repo.transaction(fn ->
        with {:ok, contents} <- PackageContents.create_package_contents(recipient, base_pkg),
             {:ok, assignment} <-
               Repo.insert(
                 PackageAssignment.changeset(
                   %PackageAssignment{},
                   assignment_params(
                     base_pkg.id,
                     contents.id,
                     recipient.id,
                     company.id,
                     requestor.id
                   )
                 )
               ) do
          # Send emails
          package_assigned_confirmation_email(recipient, us_user, company, contents, assignment)
        else
          {:error, error_key} -> Repo.rollback(error_key)
        end
      end)
    end

    text(conn, "OK")
  end

  def setup_template_for_rsd(conn, %{"rid" => recipient_id, "docId" => raw_doc_id}) do
    requestor = get_current_requestor(conn)

    company = Repo.get(Company, requestor.company_id)
    recipient = Repo.get(Recipient, recipient_id)
    raw_document = Repo.get(RawDocument, raw_doc_id)

    # update template type to rspec
    cs = RawDocument.changeset(raw_document, %{flags: 2})
    Repo.update!(cs)

    Repo.transaction(fn ->
      with {:ok, base_pkg} <-
             Repo.insert(%Package{
               title: raw_document.name,
               description: raw_document.description,
               company_id: company.id,
               templates: [raw_document.id],
               status: 0,
               is_archived: true
             }),
           {:ok, contents} <- PackageContents.create_package_contents(recipient, base_pkg) do
        # create response
        json(conn, %{
          checklist_id: base_pkg.id,
          contents_id: contents.id
        })
      else
        {:error, error_key} -> Repo.rollback(error_key)
      end
    end)
  end

  defp get_label_value_for_iac_fields(field, all_labels) do
    is_label_allowed? = IACField.is_label_value_supported?(field.field_type)

    if is_label_allowed? do
      recipient_label = all_labels[field.label]

      if recipient_label == nil do
        field.default_value
      else
        head = recipient_label |> List.first()

        if head.type == "shortAnswer" do
          head.value
        else
          field.default_value
        end
      end
    else
      field.default_value
    end
  end

  @type apiIACField :: %{
          id: integer,
          parent_id: integer,
          parent_type: integer,
          name: String.t(),
          location: %{
            type: integer,
            values: [integer]
          },
          fill_type: integer,
          type: integer,
          master_field_id: integer,
          set_value: String.t(),
          default_value: String.t(),
          internal_values: [integer],
          label: String.t(),
          label_value: String.t(),
          label_question: String.t(),
          label_question_type: String.t(),
          label_id: integer,
          repeat_entry_form_id: integer,
          allow_multiline: boolean
        }
  @spec make_iac_field(%IACField{}) :: apiIACField
  defp make_iac_field(field) do
    m = %{
      id: field.id,
      parent_id: field.parent_id,
      parent_type: field.parent_type,
      name: field.name,
      location: %{
        type: field.location_type,
        values: [
          field.location_value_1,
          field.location_value_2,
          field.location_value_3,
          field.location_value_4,
          field.location_value_5,
          field.location_value_6
        ]
      },
      fill_type: field.fill_type,
      type: field.field_type,
      master_field_id: field.master_field_id,
      set_value: field.set_value,
      default_value: field.default_value,
      internal_values: [
        field.internal_value_1
      ],
      label: field.label || "",
      label_value: field.label_value,
      label_question: field.label_question,
      label_question_type: field.label_question_type,
      label_id: field.label_id,
      repeat_entry_form_id: field.repeat_entry_form_id,
      allow_multiline: field.allow_multiline
    }

    if field.field_type == 3 do
      iacsig = Repo.get_by(IACSignature, signature_field: field.id)

      if iacsig != nil do
        sig_info = %{
          id: iacsig.id,
          data: iacsig.signature_file,
          requestor_filled: (iacsig.flags &&& 4) == 4
        }

        Map.put(m, :signature_info, sig_info)
      else
        sig_info = %{
          id: 0,
          data: "",
          requestor_filled: false
        }

        Map.put(m, :signature_info, sig_info)
      end
    else
      m
    end
  end

  def iac_show_document(conn, %{"id" => id}) do
    # TODO: verify access
    iac_doc = Repo.get(IACDocument, id)

    if iac_doc != nil do
      iacmf = Repo.get(IACMasterForm, iac_doc.master_form_id)
      document_type = IACDocument.type_document(iac_doc.document_type)

      recipient = Repo.get(Recipient, iac_doc.recipient_id)
      company = Repo.get(Company, iacmf.company_id)
      contents = Repo.get(PackageContents, iac_doc.contents_id)

      iac_assigned_form_id =
        if document_type == :raw_document_customized do
          case IACController.get_iaf_for_ifexists(recipient, company, iac_doc, contents, nil) do
            %{id: id} -> id
            _ -> nil
          end
        else
          nil
        end


      rdc_id =
        if document_type == :raw_document_customized do
          Repo.one(
            from r in RawDocumentCustomized,
              #
              where:
                r.contents_id == ^iac_doc.contents_id and r.recipient_id == ^recipient.id and
                  r.raw_document_id == ^iac_doc.raw_document_id,
              order_by: [desc: r.inserted_at],
              limit: 1,
              select: r.id
          )
        else
          nil
        end

      rd =
        if document_type == :raw_document do
          Repo.get(RawDocument, iac_doc.document_id)
        else
          nil
        end

      IO.inspect(iac_doc)
      IO.inspect(rd)

      json(conn, %{
        id: iac_doc.id,
        document_type: document_type,
        document_id: iac_doc.document_id,
        customization_id: rdc_id,
        file_name: iac_doc.file_name,
        doc_name: iacmf.name,
        fields:
          Enum.map(iacmf.fields, fn f ->
            field = Repo.get(IACField, f)
            make_iac_field(field)
          end),
        contents_id: iac_doc.contents_id,
        recipient_id: iac_doc.recipient_id,
        template_id: iac_doc.raw_document_id,
        iac_assigned_form_id: iac_assigned_form_id,
        version:
          if rd != nil do
            rd.version
          else
            0
          end
      })
    else
      conn |> put_status(404) |> text("notfound")
    end
  end

  def iac_get_iac_document(conn, %{"type" => type, "id" => id}) do
    requestor = get_current_requestor(conn)

    rsdc =
      if type == "rsd" do
        r = Repo.get(RawDocumentCustomized, id)

        if r != nil and
             Repo.get(RawDocument, r.raw_document_id).company_id != requestor.company_id do
          raise ArgumentError, message: "access prevented RSDC #{id} requestor #{requestor.id}"
        end

        r
      else
        nil
      end

    cid =
      if type == "rsd" do
        rsdc.contents_id
      else
        0
      end

    rid =
      if type == "rsd" do
        rsdc.recipient_id
      else
        0
      end

    res =
      case type do
        "template" ->
          BoilerPlateWeb.IACController.api_setup_iac_for_raw_document(requestor, id)

        "rsd" ->
          BoilerPlateWeb.IACController.api_setup_iac_for_rsdc(requestor, id, cid, rid)

        _ ->
          {:err, :bad_type}
      end

    case res do
      {:err, :not_found} ->
        conn |> put_status(404) |> json(%{error: :not_found})

      {:err, :forbidden} ->
        conn |> put_status(403) |> json(%{error: :forbidden})

      {:err, x} ->
        conn |> put_status(400) |> json(%{error: x})

      {:ok, iac_doc} ->
        json(conn, %{
          iacDocumentId: iac_doc.id
        })
    end
  end

  def iac_setup(conn, %{"id" => id}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    iac_doc = Repo.get(IACDocument, id)

    reply = BoilerPlateWeb.IACController.api_core_setup_iac(iac_doc, us_user, "default", "n", 0)

    if reply == :ok do
      text(conn, "OK")
    else
      conn |> put_status(400) |> json(%{error: reply})
    end
  end

  def iac_reset(conn, %{"id" => id}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    iac_doc = Repo.get(IACDocument, id)

    reply = BoilerPlateWeb.IACController.api_core_setup_iac(iac_doc, us_user, "acro", "yes", 0)

    if reply == :ok do
      text(conn, "OK")
    else
      conn |> put_status(400) |> json(%{error: reply})
    end
  end

  def iac_update_field(
        conn,
        params = %{
          "id" => _iac_doc_id,
          "fieldid" => field_id
        }
      ) do
    field = Repo.get(IACField, field_id)
    lv1 = params["minY"] || field.location_value_1
    lv2 = params["minX"] || field.location_value_2
    lv3 = params["fieldWidth"] || field.location_value_3
    lv4 = params["fieldHeight"] || field.location_value_4
    lv6 = params["pageNo"] || field.location_value_6
    ft = params["type"] || field.field_type
    label = params["label"] || field.label
    label_value = params["label_value"] || field.label_value
    label_question = params["label_question"] || field.label_question
    label_question_type = params["label_question_type"] || field.label_question_type

    allow_multiline =
      if params["allow_multiline"] == nil do
        field.allow_multiline
      else
        params["allow_multiline"]
      end

    if params["fill_type"] != nil || params["field_type"] != nil do
      new_fill_type = params["fill_type"] || field.fill_type
      new_ft = params["field_type"] || field.field_type

      label_question_type =
      if label_question_type == nil do
        IACField.default_question_type_for_field(new_ft)
      else
        label_question_type
      end

      cs =
        IACField.changeset(field, %{
          fill_type: new_fill_type,
          field_type: new_ft,
          label: label,
          label_value: label_value,
          label_question: label_question,
          label_question_type: label_question_type,
          allow_multiline: allow_multiline,
          label_id: nil
        })

      new_field = Repo.update!(cs)

      json(conn, %{
        id: new_field.id,
        field: make_iac_field(new_field)
      })
    else
      cs =
        IACField.changeset(field, %{
          field_type: ft,
          location_value_1: min(lv1, lv4),
          location_value_2: min(lv2, lv3),
          location_value_3: abs(lv3 - lv2),
          location_value_4: abs(lv4 - lv1),
          location_value_6: lv6,
          label: label,
          label_value: label_value,
          label_question: label_question,
          label_question_type: label_question_type,
          allow_multiline: allow_multiline,
          label_id: nil
        })

      new_field = Repo.update!(cs)

      json(conn, %{
        id: new_field.id,
        field: make_iac_field(new_field)
      })
    end
  end

  def iac_add_field(
        conn,
        params = %{
          "id" => id,
          "fieldType" => ft,
          "baseX" => bx,
          "baseY" => by,
          "finalX" => fx,
          "finalY" => fy,
          "pageNumber" => page_no
        }
      ) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    fill_type = params["fill_type"] || 0

    iac_doc = Repo.get(IACDocument, id)

    real_type =
      case ft do
        1 -> "text"
        2 -> "selection"
        3 -> "signature"
        4 -> "table"
        _ -> "garbage"
      end

    res = BoilerPlateWeb.IACController.api_add_field(us_user, iac_doc.id, real_type)

    case res do
      {:ok, nf, _needs_location} ->
        # The field was created, now set its location
        # Get the IACField
        field = Repo.get(IACField, nf.id)

        # Apply the change
        cs =
          IACField.changeset(field, %{
            location_value_1: min(by, fy),
            location_value_2: min(bx, fx),
            location_value_3: abs(fx - bx),
            location_value_4: abs(fy - by),
            location_value_6: page_no,
            fill_type: fill_type
          })

        Repo.update!(cs)

        field = Repo.get(IACField, nf.id)

        json(conn, %{
          id: field.id,
          field: make_iac_field(field)
        })

      err ->
        conn |> put_status(400) |> json(%{error: err})
    end
  end

  def iac_delete_field(conn, %{"id" => id, "fid" => field_id}) do
    requestor = get_current_requestor(conn)
    iac_doc = Repo.get(IACDocument, id)

    if requestor == nil or iac_doc == nil or
         IACDocument.company_id_of(iac_doc) != requestor.company_id do
      conn |> put_status(403) |> text("Forbidden")
    else
      imfid = iac_doc.master_form_id
      imf = Repo.get(IACMasterForm, imfid)
      ifd = Repo.get(IACField, field_id)

      fields = imf.fields |> Enum.filter(&(&1 != ifd.id))

      # Unlink the field from the IMF
      cs = IACMasterForm.changeset(imf, %{fields: fields})
      Repo.update!(cs)

      # Mark the field as deleted
      cs = IACField.changeset(ifd, %{flags: ifd.flags ||| 1})
      Repo.update!(cs)

      text(conn, "OK")
    end
  end

  def file_crash_report(conn, %{"crash" => crash}) do
    user =
      if BoilerPlate.Guardian.Plug.current_resource(conn) != nil do
        BoilerPlate.Guardian.Plug.current_resource(conn)
      else
        %{
          id: -1,
          email: "N/A",
          name: "Not Logged In"
        }
      end

    version = crash["boilerplate-version"]
    location = crash["locationIdentifier"]
    jse = crash["js_error"] |> inspect()

    slack_data = %{
      text:
        "Boilerplate (on #{Application.get_env(:boilerplate, :boilerplate_domain)}, user #{user.name} (email: #{user.email}, id: #{user.id})) JS crashed (version `#{version}`, location identifier `#{location}`): #{jse}"
    }

    HTTPoison.post(
      "https://hooks.slack.com/services/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",
      Poison.encode!(slack_data),
      [
        {"Content-Type", "application-json"}
      ],
      []
    )

    text(conn, "OK")
  end

  def lookup_requestor_pending_reviews(conn, _param) do
    requestor = get_current_requestor(conn)

    company = Repo.get(Company, requestor.company_id)

    pending_fr_reviews_query =
      from r in RequestCompletion,
        where:
          r.company_id == ^company.id and (r.status == 1 or r.status == 5) and
            r.assignment_id in subquery(
              from pa in PackageAssignment,
                where: pa.company_id == ^company.id and pa.status == 0,
                select: pa.id
            ),
        select: r.id

    pending_fr_reviews_count = Repo.aggregate(pending_fr_reviews_query, :count, :id)

    pending_doc_reviews_query =
      from r in Document,
        where:
          r.company_id == ^company.id and (r.status == 1 or r.status == 5) and
            r.assignment_id in subquery(
              from pa in PackageAssignment,
                where: pa.company_id == ^company.id and pa.status == 0,
                select: pa.id
            ),
        select: r.id

    pending_doc_reviews_count = Repo.aggregate(pending_doc_reviews_query, :count, :id)

    contents_ids =
      Repo.all(
        from pa in PackageAssignment,
          where: pa.company_id == ^company.id and pa.status == 0,
          select: pa.contents_id
      )

    pending_forms_count =
      contents_ids
      |> Enum.reduce([], fn contents_id, acc ->
        review_forms = FormController.get_forms_for_contents(contents_id, true)
        acc ++ review_forms
      end)
      |> Enum.count()

    json(
      conn,
      %{
        exists:
          pending_fr_reviews_count > 0 or pending_doc_reviews_count > 0 or pending_forms_count > 0,
        total_docs_count: pending_doc_reviews_count,
        total_requests_count: pending_fr_reviews_count,
        total_forms_count: pending_forms_count
      }
    )
  end

  def requestor_reviews(conn, _params) do
    requestor = get_current_requestor(conn)

    company = Repo.get(Company, requestor.company_id)

    assignments =
      Repo.all(
        from pa in PackageAssignment,
          # get in progress or archived checklist
          where: pa.company_id == ^company.id and (pa.status == 0 or pa.status == 1),
          select: pa
      )

    contents =
      for assign <- assignments, do: {assign.id, Repo.get(PackageContents, assign.contents_id)}

    data =
      for {aid, content} <- contents do
        n = %{
          contents_id: content.id,
          assignment_id: aid,
          recipient_id: content.recipient_id,
          requestor: %{
            name: requestor.name,
            company_id: requestor.company_id
          },
          checklist_id: content.package_id,
          recipient_description: content.recipient_description,
          requestor_description: content.req_checklist_identifier,
          documents:
            Enum.reduce(content.documents, [], fn x, acc ->
              doc =
                Repo.one(
                  from d in Document,
                    where:
                      d.company_id == ^company.id and d.status == 1 and
                        d.assignment_id == ^aid and
                        d.recipient_id == ^content.recipient_id and d.raw_document_id == ^x,
                    select: d
                )

              if doc != nil do
                rd = Repo.get(RawDocument, doc.raw_document_id)

                iac_doc_id =
                  if RawDocument.is_rspec?(rd) do
                    rdc =
                      Repo.one(
                        from r in RawDocumentCustomized,
                          where:
                            r.contents_id == ^content.id and
                              r.recipient_id == ^content.recipient_id and
                              r.raw_document_id == ^rd.id,
                          order_by: [desc: r.inserted_at],
                          limit: 1,
                          select: r
                      )

                    if iac_setup_for_customization?(rd, rdc) do
                      IACDocument.get_for(:raw_document_customized, rdc).id
                    else
                      0
                    end
                  else
                    if IACDocument.setup_for?(:raw_document, rd) do
                      IACDocument.get_for(:raw_document, rd).id
                    else
                      0
                    end
                  end

                acc ++
                  [
                    %{
                      id: doc.id,
                      is_rspec: RawDocument.is_rspec?(rd),
                      is_info: RawDocument.is_info?(doc),
                      iac_doc_id: iac_doc_id,
                      contents_id: content.id,
                      recipient_id: content.recipient_id,
                      assignment_id: aid,
                      allow_edits: rd.editable_during_review,
                      type: :document,
                      name: rd.name,
                      description: rd.description,
                      status: doc.status,
                      filename: doc.filename,
                      submitted: doc.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
                      base_document_id: doc.raw_document_id
                    }
                  ]
              else
                acc
              end
            end),
          requests:
            Enum.reduce(content.requests, [], fn x, acc ->
              req =
                Repo.one(
                  from r in RequestCompletion,
                    where:
                      r.company_id == ^company.id and (r.status == 1 or r.status == 5) and
                        r.assignment_id == ^aid and
                        r.recipientid == ^content.recipient_id and r.requestid == ^x,
                    order_by: r.inserted_at,
                    select: r
                )

              if req != nil do
                request_info = Repo.get(DocumentRequest, req.requestid)
                has_confirmation_file_uploaded? = request_info.has_file_uploads

                task_confirmation_upload_doc_id =
                  if has_confirmation_file_uploaded? do
                    doc =
                      Repo.get_by(RequestCompletion, %{
                        file_request_reference: request_info.id,
                        status: 1
                      })

                    if doc != nil do
                      doc.requestid
                    end
                  else
                    nil
                  end

                acc ++
                  [
                    %{
                      id: req.id,
                      type: :request,
                      request_type:
                        if 2 in request_info.attributes do
                          "data"
                        else
                          if 1 in request_info.attributes do
                            "task"
                          else
                            "file"
                          end
                        end,
                      has_confirmation_file_uploaded: has_confirmation_file_uploaded?,
                      is_task_confirmation_file_upload: req.file_request_reference != nil,
                      task_confirmation_upload_doc_id: task_confirmation_upload_doc_id,
                      description: request_info.description,
                      status: req.status,
                      filename: req.file_name,
                      name: request_info.title,
                      return_reason: req.return_comments,
                      submitted: req.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
                      request_id: req.requestid,
                      link: request_info.link,
                      is_enabled_tracking: request_info.enable_expiration_tracking,
                      doc_expiration_info: request_info.expiration_info
                    }
                  ]
              else
                acc
              end
            end),
          forms: FormController.get_forms_for_contents(content.id, true)
        }

        fully_submitted =
          length(n.documents) == length(content.documents) and
            length(n.requests) == length(content.requests) and
            length(n.requests) == length(content.requests)

        fully_reviewed =
          (n.documents ++ n.requests ++ n.forms)
          |> Enum.map(& &1.status)
          |> Enum.all?(&(&1 == 2 or &1 == 3))

        first_submit =
          Enum.map(n.documents ++ n.requests, & &1.submitted)
          |> Enum.sort()
          |> List.first()

        n = Map.put(n, :fully_submitted, fully_submitted)
        n = Map.put(n, :fully_reviewed, fully_reviewed)
        Map.put(n, :submitted, first_submit)
      end

    data =
      data
      |> Enum.filter(&(&1.documents != [] || &1.requests != [] || &1.forms != []))
      |> Enum.sort(fn a, b -> a.submitted >= b.submitted end)

    json(conn, data)
  end

  def requestor_lookup_remaining_reviews(conn, %{"aid" => assignment_id}) do
    requestor = get_current_requestor(conn)

    company = Repo.get(Company, requestor.company_id)

    assignment =
      Repo.one(
        from pa in PackageAssignment,
          where: pa.company_id == ^company.id and pa.id == ^assignment_id,
          select: pa
      )

    content = Repo.get(PackageContents, assignment.contents_id)

    documents =
      Enum.reduce(content.documents, [], fn x, acc ->
        docs =
          Repo.one(
            from d in Document,
              where:
                d.company_id == ^company.id and
                  d.assignment_id == ^assignment.id and
                  d.recipient_id == ^content.recipient_id and d.raw_document_id == ^x,
              order_by: [desc: d.inserted_at],
              limit: 1,
              select: d
          )

        if docs != nil do
          acc ++ [docs]
        else
          acc
        end
      end)

    requests =
      Enum.reduce(content.requests, [], fn x, acc ->
        req =
          Repo.one(
            from r in RequestCompletion,
              # status = 0 -> in progress
              where:
                r.company_id == ^company.id and r.status != 0 and
                  r.assignment_id == ^assignment.id and
                  r.recipientid == ^content.recipient_id and r.requestid == ^x,
              order_by: [desc: r.inserted_at],
              limit: 1,
              select: r
          )

        if req != nil do
          acc ++ [req]
        else
          acc
        end
      end)

    forms = FormController.get_forms_for_contents(content.id)
    submitted_forms_count = forms |> Enum.filter(& &1.is_submitted) |> length

    # check if the submitted req is same as send reqs
    is_docs_all_submitted = length(documents) == length(content.documents)
    is_forms_all_submitted = submitted_forms_count == length(content.forms)
    is_req_all_submitted = length(requests) == length(content.requests)

    all_submitted? = is_docs_all_submitted and is_forms_all_submitted and is_req_all_submitted

    last_review_pending? =
      if all_submitted? do
        new_fr =
          Enum.map(documents, & &1.status) ++
            Enum.map(forms, & &1.status) ++ Enum.map(requests, & &1.status)

        # review pending -> submitted -> 1 or missing -> 5
        review_pending_count = new_fr |> Enum.filter(&(&1 === 1 or &1 === 5)) |> Enum.count()

        review_pending_count == 1
      else
        false
      end

    json(conn, %{
      is_last_to_review: last_review_pending?,
      checklist_archived: assignment.status == 1
    })
  end

  def requestor_review_return(conn, %{"itemId" => id, "type" => type, "comments" => comments}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    if type == "form" do
      params = %{
        "form_submission_id" => id,
        "return_comments" => comments
      }

      reply = FormController.return_form_submission(us_user, params)

      if reply == :ok do
        json(conn, %{
          reply: reply
        })
      else
        conn |> put_status(500) |> text(reply)
      end
    end

    #
    new_type =
      if type == "request" do
        :request
      else
        :document
      end

    reply = BoilerPlateWeb.DocumentController.api_document_return(us_user, id, comments, new_type)

    if reply == :ok do
      json(conn, %{
        reply: reply
      })
    else
      conn |> put_status(500) |> text(reply)
    end
  end

  def requestor_review_accept(conn, params = %{"itemId" => id, "type" => type}) do
    requestor = get_current_requestor(conn)
    export_action = params["export"] || "default"

    reply =
      case type do
        "document" ->
          BoilerPlateWeb.DocumentController.api_document_approve(requestor, id, export_action)

        "request" ->
          BoilerPlateWeb.DocumentController.api_request_approve(requestor, id, export_action)

        "form" ->
          FormController.accept_form_submission(requestor, id)
      end

    if reply == :ok do
      json(conn, %{
        reply: reply
      })
    else
      conn |> put_status(500) |> text(reply)
    end
  end

  def requestor_review_assignment_lock(conn, %{"aid" => aid}) do
    requestor = get_current_requestor(conn)

    company = Repo.get(Company, requestor.company_id)
    assignment = Repo.get(PackageAssignment, aid)

    docs =
      Repo.all(
        from r in Document,
          where:
            r.company_id == ^company.id and (r.status == 1 or r.status == 5) and
              r.assignment_id == ^aid and
              r.recipient_id == ^assignment.recipient_id and r.flags == 0,
          select: r
      )

    for doc <- docs do
      Repo.update(Document.changeset(doc, %{flags: 1}))
    end

    conn |> text("OK")
  end

  def post_esign_consent(conn, %{
        "userType" => "recipient",
        "recipientId" => recipientId,
        "consented" => consentVal
      }) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    recipient = Repo.get(Recipient, recipientId)

    if recipient != nil and us_user.id == recipient.user_id and consentVal do
      cs =
        Recipient.changeset(recipient, %{
          esign_consented: consentVal,
          esign_consent_date: DateTime.utc_now() |> DateTime.truncate(:second),
          esign_consent_remote_ip: conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
        })

      Repo.update!(cs)

      text(conn, "OK")
    else
      text(conn, "OK")
    end
  end

  def post_esign_consent(conn, %{
        "userType" => "requestor",
        "recipientId" => _recipientId,
        "consented" => consentVal
      }) do
    requestor = get_current_requestor(conn)

    # TODO: verify access policy
    if consentVal and requestor != nil do
      cs =
        Requestor.changeset(requestor, %{
          esign_consented: consentVal,
          esign_consent_date: DateTime.utc_now() |> DateTime.truncate(:second),
          esign_consent_remote_ip: conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
        })

      Repo.update!(cs)

      text(conn, "OK")
    else
      text(conn, "OK")
    end
  end

  def get_esign_consent(conn, %{"userType" => "recipient", "rid" => recipientId}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    recipient = Repo.get(Recipient, recipientId)

    # TODO: verify access policy
    if recipient != nil and us_user.id == recipient.user_id do
      has_saved_sig =
        recipient.esign_saved_signature != "" and recipient.esign_saved_signature != nil

      saved_sig = recipient.esign_saved_signature

      json(conn, %{
        consented: recipient.esign_consented,
        consent_date: recipient.esign_consent_date,
        consent_remote_ip: recipient.esign_consent_remote_ip,
        has_saved_signature: has_saved_sig,
        saved_signature:
          if has_saved_sig do
            saved_sig
          else
            ""
          end
      })
    else
      conn |> put_status(404) |> text("Not found")
    end
  end

  def get_esign_consent(conn, %{"userType" => "requestor", "rid" => _recipientId}) do
    requestor = get_current_requestor(conn)

    # TODO: verify access policy
    if requestor != nil do
      has_saved_sig =
        requestor.esign_saved_signature != "" and requestor.esign_saved_signature != nil

      saved_sig = requestor.esign_saved_signature

      json(conn, %{
        consented: requestor.esign_consented,
        consent_date: requestor.esign_consent_date,
        consent_remote_ip: requestor.esign_consent_remote_ip,
        has_saved_signature: has_saved_sig,
        saved_signature:
          if has_saved_sig do
            saved_sig
          else
            ""
          end
      })
    else
      conn |> put_status(404) |> text("Not found")
    end
  end

  def iac_add_signature(conn, %{
        "audit_start" => _as,
        "audit_end" => _ae,
        "data" => sigData,
        "isreq" => isreq,
        "save_signature" => save,
        "id" => field_id
      }) do
    remote_ip = conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
    recipient = get_current_recipient(conn)

    res =
      if isreq do
        requestor = get_current_requestor(conn)

        signee = %{
          version: 1,
          type: IACSignature.atom_to_signee_type(:requestor),
          id: requestor.id
        }

        BoilerPlateWeb.IACController.api_set_signature(
          requestor,
          field_id,
          sigData,
          isreq,
          remote_ip,
          save,
          requestor.id,
          signee
        )
      else
        signee = %{
          version: 1,
          type: IACSignature.atom_to_signee_type(:recipient),
          id: recipient.id
        }

        BoilerPlateWeb.IACController.api_set_signature(
          recipient,
          field_id,
          sigData,
          isreq,
          remote_ip,
          save,
          recipient.id,
          signee
        )
      end

    if res == :ok do
      conn |> json(%{status: :ok})
    else
      conn |> put_status(400) |> json(%{error: res})
    end
  end

  def make_dashboard_state_for(assignments, recipient \\ nil) do
    all_status = Enum.map(assignments, fn x -> x.state.status end)

    new_delivery_fault =
      if recipient != nil do
        Enum.any?(assignments, fn x -> x.state.delivery_fault == true end)
      else
        false
      end

    new_status =
      if recipient != nil do
        cond do
          recipient.status == 1 -> 11
          Enum.any?(all_status, fn x -> x == 2 end) -> 2
          Enum.all?(all_status, fn x -> x == 0 end) -> 0
          Enum.all?(all_status, fn x -> x == 9 end) -> 9
          Enum.all?(all_status, fn x -> x == 10 end) -> 10
          Enum.all?(all_status, fn x -> x == 9 || x == 10 end) -> 10
          Enum.all?(all_status, fn x -> x == 9 || x == 10 || x == 4 || x == 6 end) -> 4
          True -> 1
        end
      else
        cond do
          Enum.any?(all_status, fn x -> x == 2 end) -> 2
          Enum.all?(all_status, fn x -> x == 0 end) -> 0
          Enum.all?(all_status, fn x -> x == 9 end) -> 9
          Enum.all?(all_status, fn x -> x == 10 end) -> 10
          Enum.all?(all_status, fn x -> x == 9 || x == 10 end) -> 10
          Enum.all?(all_status, fn x -> x == 9 || x == 10 || x == 4 || x == 6 end) -> 4
          True -> 1
        end
      end

    best_time_dr =
      assignments
      |> Enum.flat_map(fn x -> x.document_requests end)
      |> Enum.map(fn x -> x.inserted_at end)
      |> Enum.sort()
      |> Enum.reverse()
      |> Enum.at(0)

    best_time_fr =
      assignments
      |> Enum.flat_map(fn x -> x.file_requests end)
      |> Enum.map(fn x -> x.inserted_at end)
      |> Enum.sort()
      |> Enum.reverse()
      |> Enum.at(0)

    %{
      status: new_status,
      date: "",
      delivery_fault: new_delivery_fault,
      latest:
        if best_time_fr > best_time_dr do
          best_time_fr
        else
          best_time_dr
        end
    }
  end

  def find_in_checklists(checklists, str) do
    Enum.any?(checklists, fn checklist ->
      %{
        name: name,
        subject: subject,
        file_requests: file_requests,
        document_requests: document_requests,
        forms: forms,
        recipient_reference: recipient_reference,
        requestor_reference: requestor_reference
      } = checklist

      in_file_requests = Helpers.findInDocuments?(file_requests, str)
      in_doc_requests = Helpers.findInDocuments?(document_requests, str)
      in_forms = FormController.findInForms?(forms, str)

      Helpers.stringContains?(name, str) ||
        Helpers.stringContains?(subject, str) ||
        Helpers.stringContains?(recipient_reference, str) ||
        Helpers.stringContains?(requestor_reference, str) ||
        in_file_requests ||
        in_doc_requests ||
        in_forms
    end)
  end

  def find_in_assignments(assignments, search_keywords) do
    # Know this was done in desparation, the gain outweighed the cost. Presenting `CPU Nightmare`
    Enum.filter(assignments, fn recipient_assignment ->
      %{recipient: recipient, cabinet: cabinet, checklists: checklists} = recipient_assignment
      %{company: company, name: name, email: email} = recipient

      search_keywords
      |> Enum.all?(fn str ->
        in_checklists = find_in_checklists(checklists, str)
        in_cabinet = Helpers.findInDocuments?(cabinet, str)

        Helpers.stringContains?(name, str) || Helpers.stringContains?(email, str) ||
          Helpers.stringContains?(company, str) ||
          in_checklists || in_cabinet
      end)
    end)
  end

  def filter_open_status_additional_file_req(ch) do
    req = ch.file_requests |> Enum.filter(&(&1.flags != 4))
    new_req = req ++ ch.document_requests ++ ch.forms

    if Enum.count(new_req) > 0 do
      true
    else
      false
    end
  end

  def do_make_assignments_of_requestor(assignments, recipient) do
    for assignment <- assignments do
      contents = Repo.get(PackageContents, assignment.contents_id)
      pkg = Repo.get(Package, assignment.package_id)
      requestor = Repo.get(Requestor, assignment.requestor_id)

      document_requests =
        BoilerPlate.AssignmentUtils.get_checklist_document_requests(
          assignment,
          recipient,
          contents
        )

      file_requests =
        BoilerPlate.AssignmentUtils.get_checklist_file_requests(assignment, recipient, contents)
        # exclude additional file request
        |> Enum.filter(&(&1.flags != 4))

      forms = FormController.get_forms_for_contents(contents.id)

      [document_requests, file_requests, forms] =
        if assignment.status == 2 do
          # to handle status for handling manual deletion of open assignment
          AssignmentUtils.deleted_checklist_request_status(
            document_requests,
            file_requests,
            forms
          )
        else
          [document_requests, file_requests, forms]
        end

      a_status =
        BoilerPlate.AssignmentUtils.requestor_assignment_status(
          document_requests,
          file_requests,
          forms
        )

      req_nearest_expiring_date =
        BoilerPlate.AssignmentUtils.calculate_nearest_expiration_date(%{
          file_requests: file_requests
        })

      BoilerPlate.AssignmentUtils.build_assignment_response(
        contents,
        assignment,
        pkg,
        requestor,
        a_status,
        document_requests,
        file_requests,
        forms,
        %{
          nearest_expiration_date: req_nearest_expiring_date
        }
      )
    end
  end

  defp get_ordered_array(filter_params, filter_order_list, key \\ "apiKey") do
    grouped_obj = Enum.group_by(filter_params, fn fstr -> fstr[key] end)

    current_filter_keys_order =
      Enum.filter(filter_order_list, fn x -> x in Map.keys(grouped_obj) end)

    Enum.flat_map(current_filter_keys_order, &grouped_obj[&1])
  end

  defp serialize_array_by_hashing(filter_params, filter_order_keys_list) do
    # create a order list get_ordered_array
    ordered_array = get_ordered_array(filter_params, filter_order_keys_list)
    # serialization
    params_ser = Jason.encode!(ordered_array)
    # hash the ordered data
    :crypto.hash(:sha3_256, params_ser) |> Base.encode16() |> String.downcase()
  end

  defp create_filter_params_cache_key(filter_params) do
    if filter_params == [] do
      ""
    else
      filter_order_keys_list = BoilerPlate.FilterUtils.get_ordered_filter_list()
      data = serialize_array_by_hashing(filter_params, filter_order_keys_list)
      "-#{data}"
    end
  end

  def requestor_dashboard_for_recipient(conn, params = %{"rid" => recipient_id}) do
    recipient = Repo.get(Recipient, recipient_id)
    recipient_company = Repo.get(Company, recipient.company_id)
    ignore_cache = params["ignore_cache"] || false
    show_deleted_checklists = params["show_deleted_checklists"] || false

    if BoilerPlate.AccessPolicy.can_we_access?(:company, recipient_company, conn) do
      filter_params = params["filterStr"] || []
      hashed_params = create_filter_params_cache_key(filter_params)

      {:ok, {:ok, cache_data}} =
        BoilerPlate.DashboardCache.get_recipient(
          :dashboard_cache,
          "#{recipient.id}#{hashed_params}"
        )

      if ignore_cache == true or cache_data == nil or show_deleted_checklists == true do
        recipient_user_email = Repo.get(User, recipient.user_id).email
        recipient_filter_params = [%{"apiKey" => "email", "value" => [recipient_user_email]}]

        parameters =
          Map.update(params, "filterStr", recipient_filter_params, fn filter_params ->
            filter_params ++ recipient_filter_params
          end)

        requestor_recipient_dashboard(conn, parameters)
      else
        text(conn, cache_data)
      end
    else
      conn |> put_status(403) |> text(:forbidden)
    end
  end

  def requestor_dashboard_meta(conn, params) do
    requestor = get_current_requestor(conn)

    if requestor != nil do
      do_requestor_dashboard(true, conn, params, false)
    else
      conn |> put_status(403) |> text(:forbidden)
    end
  end

  def requestor_dashboard(conn, params) do
    requestor = get_current_requestor(conn)

    if requestor != nil do
      do_requestor_dashboard(false, conn, params, false)
    else
      conn |> put_status(403) |> text(:forbidden)
    end
  end

  def requestor_recipient_dashboard(conn, params) do
    requestor = get_current_requestor(conn)

    if requestor != nil do
      do_requestor_dashboard(false, conn, params, true)
    else
      conn |> put_status(403) |> text(:forbidden)
    end
  end

  def get_recipient_cache(recipient, fetch_all, filter_params, show_deleted_checklists \\ false) do
    if fetch_all or filter_params != [] or show_deleted_checklists != false do
      nil
    else
      {:ok, {:ok, cache_data}} =
        BoilerPlate.DashboardCache.get_recipient(:dashboard_cache, recipient.id)

      cache_data
    end
  end

  def calculate_next_event_for_recipient(assignments) do
    nearest_expiration_date =
      BoilerPlate.AssignmentUtils.calculate_nearest_expiration_date(assignments)

    nearest_due_date =
      assignments
      |> Enum.map(& &1.due_date)
      |> Enum.filter(&(&1 != %{}))
      |> Enum.map(& &1.date)
      |> Enum.min(fn -> :no_due end)

    %{
      nearest_expiration_date: nearest_expiration_date,
      nearest_due_date:
        if nearest_due_date != :no_due do
          nearest_due_date
        else
          nil
        end
    }
  end

  def get_next_status_for_contact(event_metadata) when event_metadata == %{}, do: nil

  def get_next_status_for_contact(event_metadata) do
    %{nearest_due_date: nearest_due, nearest_expiration_date: nearest_exp} = event_metadata

    due_timex_struc =
      if nearest_due != nil do
        CustomDateTimex.parse_date_from_str(nearest_due)
      end

    exp_timex_struc =
      if nearest_exp != nil do
        CustomDateTimex.parse_date_from_str(nearest_exp)
      end

    cond do
      due_timex_struc == nil and exp_timex_struc == nil -> nil
      due_timex_struc == nil -> exp_timex_struc
      exp_timex_struc == nil -> due_timex_struc
      Timex.compare(due_timex_struc, exp_timex_struc, :day) == -1 -> nearest_exp
      true -> nearest_due
    end
  end

  def get_recipient_dashboard_data(
        recipient,
        assignments,
        company,
        filter_params,
        show_deleted_checklists \\ false
      ) do
    cabinet_of_recipient = make_cabinet_of(recipient, company)

    checklists =
      checklist_filter(assignments, recipient, filter_params, show_deleted_checklists)
      |> Enum.filter(fn x -> filter_open_status_additional_file_req(x) end)

    document_count =
      Enum.reduce(checklists, 0, fn x, acc ->
        acc + Enum.count(x.document_requests)
      end)

    file_request_count =
      Enum.reduce(checklists, 0, fn x, acc ->
        acc + Enum.count(x.file_requests)
      end)

    # check for updated dates since the most recent reviews any other should be deplay
    %{last_updated: latest_activity_date} =
      if checklists == [] do
        %{last_updated: DateTime.from_unix!(0)}
      else
        Enum.max_by(checklists, fn x -> x[:last_updated] end)
      end

    dashboard_state = make_dashboard_state_for(checklists, recipient)
    next_event_metadata = calculate_next_event_for_recipient(checklists)
    tags = Repo.all(from r in RecipientTag, where: r.id in ^recipient.tags, select: r)

    final_data = %{
      recipient: make_recipient(recipient),
      state: dashboard_state,
      checklists: checklists |> Enum.sort_by(fn x -> x[:received_date][:date] end, &>=/2),
      recipient_state: dashboard_state,
      loadState: 0,
      document_count: document_count,
      file_request_count: file_request_count,
      checklist_count: length(checklists),
      cabinet: cabinet_of_recipient,
      latest_activity_date: latest_activity_date,
      next_event_metadata: next_event_metadata,
      next_status: get_next_status_for_contact(next_event_metadata),
      tags: BoilerPlateWeb.DocumentTagView.render("recipient_tags.json", recipient_tags: tags)
    }

    if filter_params == [] and show_deleted_checklists == false do
      BoilerPlate.DashboardCache.set_recipient(:dashboard_cache, recipient.id, final_data)
    end

    final_data
  end

  def format_recipient_cache(obj, meta_request) do
    if meta_request do
      %{
        recipient: obj[:recipient],
        state: obj[:state],
        checklist_count: length(obj[:checklists]),
        is_partial:
          if obj[:checklists] == nil do
            false
          else
            Enum.all?(obj[:checklists], fn x -> x.state.status == 2 end)
          end,
        recipient_state: obj[:recipient_state],
        latest_activity_date: obj[:latest_activity_date],
        next_event_metadata: obj[:next_event_metadata],
        next_status: obj[:next_status],
        tags: obj[:tags]
      }
    else
      obj
    end
  end

  def get_assignments_for_company(
        company,
        params,
        meta_request
      ) do
    search = params["search"] || ""
    filter_params = params["filterStr"] || []
    fetch_all = params["all"] == "true" || false
    show_deleted_checklists = params["show_deleted_checklists"] || false
    where_clause = FilterEngine.filter_where(filter_params)
    hashed_params = create_filter_params_cache_key(filter_params)
    r_show_in_dashboard = if params["show_in_dashboard"] == false, do: false, else: true

    meta_request =
      if search == "" or search == nil do
        meta_request
      else
        false
      end

    IO.puts("meta_request? #{meta_request} search [#{search}]")

    all_active_assignments =
      PackageAssignment
      |> where([pa], pa.company_id == ^company.id)
      |> join(:inner, [pa], r in Recipient,
        as: :recp,
        on:
          pa.recipient_id == r.id and
            r.show_in_dashboard == ^r_show_in_dashboard and
            r.status != 1 and
            pa.status != 1
      )
      |> QueryEngine.build_join_clause(filter_params)
      |> where(^where_clause)
      |> Repo.all()
      |> Enum.group_by(fn pa -> pa.recipient_id end)

    assignment_data =
      Enum.map(all_active_assignments, fn {recipient_id, assignments} ->
        recipient = Repo.get(Recipient, recipient_id)

        # discard cache if filter is being used
        recipient_cache_data =
          recipient |> get_recipient_cache(fetch_all, filter_params, show_deleted_checklists)

        if recipient_cache_data == nil do
          final_data =
            get_recipient_dashboard_data(
              recipient,
              assignments,
              company,
              filter_params,
              show_deleted_checklists
            )

          # Cache this data
          if show_deleted_checklists == false do
            BoilerPlate.DashboardCache.set_recipient(
              :dashboard_cache,
              "#{recipient.id}#{hashed_params}",
              final_data
            )
          end

          final_data
        else
          obj = Poison.decode!(recipient_cache_data, %{keys: :atoms})

          obj |> format_recipient_cache(meta_request)
        end
      end)

    assignment_data
  end

  def sort_requestor_assignments(assignment_data, sort, sort_direction) do
    assignment_data
    # filter out empty checklists from dashboard
    |> Enum.filter(fn x -> x.checklist_count > 0 end)
    # |> Enum.sort_by(fn x -> x[:latest_activity_date] end, &>=/2)
    |> Enum.sort_by(
      fn a ->
        %{latest_activity_date: l, recipient: r, state: s, next_status: ns} = a

        case sort do
          :latest_activity_date ->
            String.downcase(l)

          :recipient_email ->
            String.downcase(r.email)

          :recipient_name ->
            String.downcase(r.name)

          :status ->
            s.status

          :recipient_organization ->
            String.downcase(r.company)

          :NEXTSTATUS ->
            IO.inspect(ns, label: "next status ...")
            ns

          _ ->
            l
        end
      end,
      sort_direction
    )
  end

  def search_requestor_assignments(assignment_data, search) do
    if search != "" do
      # search data now
      search_keywords = search |> String.split(" ") |> Enum.map(fn s -> String.downcase(s) end)
      assignment_data |> find_in_assignments(search_keywords)
    else
      # filter out empty checklists from dashboard
      assignment_data
      |> Enum.filter(fn x -> x[:checklist_count] > 0 end)
    end
  end

  def paginate_requestor_assignments(assignment_data, page, per_page, fetch_all) do
    if fetch_all do
      assignment_data
    else
      assignment_data |> Enum.slice((page - 1) * per_page, per_page)
    end
  end

  def do_requestor_dashboard(meta_request, conn, params, recipient_assignment_request) do
    company = get_current_requestor(conn, as: :company)
    search = params["search"] || ""
    sort = String.to_atom(params["sort"] || "latest_activity_date")
    sort_direction = String.to_atom(params["sort_direction"] || "desc")
    export = params["export"] || false
    fetch_all = params["all"] == "true" || false

    {page, _} = Integer.parse(Helpers.get_param(params, "page", "1"))
    {per_page, _} = Integer.parse(Helpers.get_param(params, "per_page", "20"))

    assignment_data =
      get_assignments_for_company(
        company,
        params,
        meta_request
      )

    sorted_assignment_data =
      assignment_data
      |> sort_requestor_assignments(sort, sort_direction)

    assignment_data =
      sorted_assignment_data
      |> search_requestor_assignments(search)

    cond do
      export == true ->
        data = get_csv_data(assignment_data, company.name)
        conn |> json(data)

      recipient_assignment_request == true ->
        recipient_obj = sorted_assignment_data |> List.first()
        # TODO this line here can return null, fix in future
        json(conn, recipient_obj)

      true ->
        total_pages = ceil(Enum.count(assignment_data) / per_page)

        paged_data =
          if fetch_all do
            assignment_data
          else
            assignment_data |> Enum.slice((page - 1) * per_page, per_page)
          end

        json(
          conn,
          %{
            total_pages: total_pages,
            page: page,
            has_next: page < total_pages,
            data: paged_data
          }
        )
    end
  end

  def get_csv_data(assignment_data, company_name) do
    header_row = [
      "recipient_name",
      "recipient_email",
      "recipient_company",
      "recipient_status",
      "latest_activity_date",
      "checklist_recipient_reference",
      "checklist_sender_name",
      "checklist_sender_org",
      "checklist_sender_reference",
      "checklist_status",
      "request_name",
      "request_type",
      "request_status"
    ]

    csv_rows =
      assignment_data
      |> Enum.reduce([], fn r_assignment, acc ->
        checklists = r_assignment.checklists
        r_state = r_assignment.state
        latest_activity_date = r_assignment.latest_activity_date
        recipient_name = r_assignment.recipient.name
        recipient_email = r_assignment.recipient.email
        recipient_company = r_assignment.recipient.company

        c_rows =
          checklists
          |> Enum.reduce([], fn checklist, c_acc ->
            c_state = checklist.state
            file_requests = checklist.file_requests
            document_requests = checklist.document_requests

            d_rows =
              document_requests
              |> Enum.reduce([], fn d_req, d_acc ->
                state = d_req.state
                return_comments = d_req.return_comments
                request_type = "Document"
                name = d_req.name

                params = %{
                  "return_comments" => return_comments
                }

                # csv_row = %{
                #   recipient_name: recipient_name,
                #   recipient_email: recipient_email,
                #   recipient_company: recipient_company,
                #   recipient_status: r_state.status,
                #   latest_activity_date: latest_activity_date,
                #   checklist_recipient_reference: checklist.recipient_reference,
                #   checklist_sender_name: checklist.sender.name,
                #   checklist_sender_org: checklist.sender.organization,
                #   checklist_sender_reference: checklist.requestor_reference,
                #   checklist_status: c_state.status,
                #   request_name: d_req.name,
                #   request_type: "Document",
                #   request_status: state.status,
                # }

                csv_row = [
                  recipient_name,
                  recipient_email,
                  recipient_company,
                  Helpers.get_status_text(r_state, %{}),
                  latest_activity_date,
                  checklist.recipient_reference,
                  checklist.sender.name,
                  checklist.sender.organization,
                  checklist.requestor_reference,
                  Helpers.get_status_text(c_state, %{}),
                  name,
                  request_type,
                  Helpers.get_status_text(state, params)
                ]

                d_acc ++ [csv_row]
              end)

            f_rows =
              file_requests
              |> Enum.reduce([], fn f_req, f_acc ->
                state = f_req.state
                missing_reason = f_req.missing_reason
                return_comments = f_req.return_comments
                is_manually_submitted = f_req.is_manually_submitted
                request_type = "Request"
                name = f_req.name

                params = %{
                  "return_comments" => return_comments,
                  "is_manually_submitted" => is_manually_submitted,
                  "missing_reason" => missing_reason
                }

                # csv_row = %{
                #   recipient_name: recipient_name,
                #   recipient_email: recipient_email,
                #   recipient_company: recipient_company,
                #   recipient_status: r_state.status,
                #   latest_activity_date: latest_activity_date,
                #   checklist_recipient_reference: checklist.recipient_reference,
                #   checklist_sender_name: checklist.sender.name,
                #   checklist_sender_org: checklist.sender.organization,
                #   checklist_sender_reference: checklist.requestor_reference,
                #   checklist_status: c_state.status,
                #   request_name: f_req.name,
                #   request_type: "Request",
                #   request_status: state.status,
                # }
                csv_row = [
                  recipient_name,
                  recipient_email,
                  recipient_company,
                  Helpers.get_status_text(r_state, %{}),
                  latest_activity_date,
                  checklist.recipient_reference,
                  checklist.sender.name,
                  checklist.sender.organization,
                  checklist.requestor_reference,
                  Helpers.get_status_text(c_state, %{}),
                  name,
                  request_type,
                  Helpers.get_status_text(state, params)
                ]

                f_acc ++ [csv_row]
              end)

            c_acc ++ d_rows ++ f_rows
          end)

        acc ++ c_rows
      end)

    # [header_row | csv_rows]
    data = [header_row | csv_rows]

    csv_data =
      data
      |> Enum.map_join("\r\n", fn row ->
        row
        |> Enum.map_join(",", fn col ->
          col = String.replace(col || "", "\"", "\\\"")
          "\"#{col}\""
        end)
      end)

    current_timestamp = DateTime.utc_now()
    ts = Calendar.strftime(current_timestamp, "%Y_%m_%d_%H_%M_%S")
    filename = String.replace(company_name, " ", "_") <> "_dashboard_export_" <> ts <> ".csv"

    %{
      data: csv_data,
      filename: filename
    }
  end

  def checklist_filter(assignments, recipient, params, show_deleted_checklists \\ false) do
    checklists = do_make_assignments_of_requestor(assignments, recipient)

    checklists =
      if show_deleted_checklists do
        checklists
      else
        checklists |> Enum.filter(&(&1.state.status != 9 && &1.state.status != 10))
      end

    has_status_filter? = params |> Enum.any?(&(&1["apiKey"] == "checkliststatus"))

    if has_status_filter? do
      # Need better approach to get status
      status =
        params |> Enum.map(& &1["value"]) |> List.first() |> List.first() |> String.to_integer()

      checklists |> Enum.filter(&(&1.state.status == status))
    else
      checklists
    end
  end

  # deprecated Todo: remove
  def requestor_dashboard_v2(conn, params) do
    requestor = get_current_requestor(conn)

    company = Repo.get(Company, requestor.company_id)
    filter_params = params["filterStr"] || []
    where_clause = FilterEngine.filter_where(filter_params)

    all_active_assignments =
      PackageAssignment
      |> where([pa], pa.company_id == ^company.id and pa.status == 0)
      |> join(:inner, [pa], r in Recipient,
        as: :recp,
        on: pa.recipient_id == r.id and r.show_in_dashboard == true
      )
      |> QueryEngine.build_join_clause(filter_params)
      |> where(^where_clause)
      |> Repo.all()
      |> Enum.group_by(fn pa -> pa.recipient_id end)

    data =
      Enum.map(all_active_assignments, fn {recipient_id, assignments} ->
        recipient = Repo.get(Recipient, recipient_id)

        cabinet_of_recipient = make_cabinet_of(recipient, Repo.get(Company, recipient.company_id))
        checklists = checklist_filter(assignments, recipient, filter_params)

        %{
          recipient: make_recipient(recipient),
          state: make_dashboard_state_for(checklists),
          checklists: checklists,
          recipient_state: make_dashboard_state_for(checklists),
          loadState: 0,
          cabinet: cabinet_of_recipient
        }
      end)
      |> Enum.filter(&(&1.checklists != []))

    json(conn, data)
  end

  def iac_delete_signature(conn, %{"fieldIds" => signatureIds, "iacDocId" => iac_doc_id, "fillType" => fill_type}) do
    Logger.info("Iac signature delete Api controller")
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    iac_doc = Repo.get(IACDocument, iac_doc_id)
    iac_af = Repo.get_by(IACAssignedForm, %{master_form_id: iac_doc.master_form_id, contents_id: iac_doc.contents_id})

    is_valid_ids? = Enum.all?(signatureIds, &(&1 in iac_af.fields))

    res =
      if is_valid_ids? do
        BoilerPlateWeb.IACController.api_del_signature(us_user, fill_type, signatureIds)
      else
        :invalid_ids
      end

    case res do
      :deleted -> conn |> put_status(200) |> json(%{status: :deleted})
      :forbidden -> conn |> put_status(403) |> json(%{error: res})
      :no_record_deleted -> conn |> put_status(404) |> json(%{error: res})
      :invalid_ids -> conn |> put_status(404) |> json(%{error: res})
    end
  end

  def iac_get_fields(conn, %{"assign" => aid, "id" => iac_doc_id}) do
    assign = Repo.get(PackageAssignment, aid)
    recipient = Repo.get(Recipient, assign.recipient_id)
    company = Repo.get(Company, recipient.company_id)
    contents = Repo.get(PackageContents, assign.contents_id)
    iac_doc = Repo.get(IACDocument, iac_doc_id)
    imf = Repo.get(IACMasterForm, iac_doc.master_form_id)
    ip = conn.remote_ip |> Tuple.to_list() |> Enum.join(".")

    iaf = BoilerPlateWeb.IACController.get_iaf_for(recipient, company, iac_doc, contents, imf)
    fields = Enum.map(Enum.map(iaf.fields, &Repo.get(IACField, &1)), &make_iac_field/1)
    # Create an EAI if enabled
    if FunWithFlags.enabled?(:audit_trail_v2) do
      BoilerPlateWeb.IACController.esign_update_or_create(
        :open_event,
        iac_doc,
        iaf,
        :recipient,
        recipient,
        ip
      )
    end

    json(conn, fields)
  end

  @spec make_iac_field_for_requestor(%IACField{}, %{String.t() => BoilerPlate.RecipientData.api()}) ::
          apiIACField
  def make_iac_field_for_requestor(field, recipient_labels) do
    default_value = get_label_value_for_iac_fields(field, recipient_labels)
    updated_field = %{field | default_value: "#{default_value}"}
    make_iac_field(updated_field)
  end

  def iac_get_fields_requestor(conn, %{
        "cid" => cid,
        "rid" => rid,
        "id" => iac_doc_id
      }) do
    recipient = Repo.get(Recipient, rid)
    company = Repo.get(Company, recipient.company_id)
    iac_doc = Repo.get(IACDocument, iac_doc_id)
    contents = Repo.get(PackageContents, cid)
    imf = Repo.get(IACMasterForm, iac_doc.master_form_id)
    requestor = get_current_requestor(conn)
    ip = conn.remote_ip |> Tuple.to_list() |> Enum.join(".")

    iaf = BoilerPlateWeb.IACController.get_iaf_for(recipient, company, iac_doc, contents, imf)

    recipient_labels =
      RecipientController.requestor_recipient_data_for_rsd_template(recipient)
      |> Enum.group_by(fn labels -> labels.label end)

    fields =
      Enum.map(
        Enum.map(iaf.fields, &Repo.get(IACField, &1)),
        &make_iac_field_for_requestor(&1, recipient_labels)
      )

    if FunWithFlags.enabled?(:audit_trail_v2) do
      BoilerPlateWeb.IACController.esign_update_or_create(
        :open_event,
        iac_doc,
        iaf,
        :requestor,
        requestor,
        ip
      )
    end

    json(conn, fields)
  end

  def iac_save_fill(
        conn,
        params = %{
          "id" => iac_doc_id,
          "assignmentId" => assignment_id,
          "fields" => fields,
          "type" => type
        }
      ) do
    iac_doc = Repo.get(IACDocument, iac_doc_id)
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    ses_mode? = params["sesMode"] || false
    _update_mode? = params["editMode"] || false
    ip = conn.remote_ip |> Tuple.to_list() |> Enum.join(".")

    {:ok, claims} =
      BoilerPlate.Guardian.decode_and_verify(BoilerPlate.Guardian.Plug.current_token(conn))

    iat = claims["iat"]
    # assignment = Repo.get(PackageAssignment, assignmentId)
    # recipient = Repo.get(Recipient, assignment.recipient_id)
    # company = Repo.get(Company, recipient.company_id)

    for f <- fields do
      field = Repo.get(IACField, f["field_id"])

      cs =
        if type == "recipient" do
          IACField.changeset(field, %{
            set_value: f["field_value"]
          })
        else
          IACField.changeset(field, %{
            set_value: f["field_value"],
            default_value: f["field_value"]
          })
        end

      Repo.update!(cs)
    end

    case type do
      "recipient" ->
        # Do nothing, as the recipient will do a submission separately.
        text(conn, "OK")

      "requestor" ->
        # This is a prefill operation or SES operation.

        # in this case the assignmentId is actually a contentsId
        contents = Repo.get(PackageContents, assignment_id)
        requestor = get_current_requestor(conn)

        iaf =
          Repo.get_by(IACAssignedForm, %{
            recipient_id: contents.recipient_id,
            # TODO: do we need this?
            # company_id: company.id,
            master_form_id: iac_doc.master_form_id,
            contents_id: contents.id,
            status: 0
          })

        cs =
          IACAssignedForm.changeset(iaf, %{
            flags: iaf.flags ||| 1
          })

        Repo.update!(cs)

        if ses_mode? == false do
          # This is a prefill operation.
          iaf = Repo.get(IACAssignedForm, iaf.id)
          fields = IACAssignedForm.fields_of(iaf)

          if FunWithFlags.enabled?(:audit_trail_v2) do
            BoilerPlateWeb.IACController.esign_create(
              :submit_event,
              iac_doc,
              iaf,
              :requestor,
              requestor,
              ip
            )
          end

          # Create the final document and insert a Document into the database
          # with the final document.
          body =
            BoilerPlateWeb.IACController.make_bp01(
              BoilerPlateWeb.IACController.make_data(fields),
              iac_doc,
              nil
            )

          # Create a new temporary file
          {:ok, tmp_pdf_path} = Briefly.create(prefix: "boilerplate")
          File.write!(tmp_pdf_path, body)

          # Handoff work
          top_doc_id = IACDocument.base_document_id(iac_doc)

          template_fn = UUID.uuid4() <> ".pdf"
          new_version_number = RawDocumentCustomized.get_verison_number_customized_doc(top_doc_id, contents.id, contents.recipient_id)

          BoilerPlateWeb.PackageController.api_upload_customize_package(
            requestor,
            us_user,
            contents.id,
            contents.recipient_id,
            top_doc_id,
            %{filename: template_fn, path: tmp_pdf_path, iac: true},
            new_version_number
          )

          rsdc =
            Repo.one(
              from r in RawDocumentCustomized,
                where:
                  r.raw_document_id == ^top_doc_id and
                    r.contents_id == ^contents.id and
                    r.recipient_id == ^contents.recipient_id,
                order_by: [desc: r.inserted_at],
                limit: 1,
                select: r
            )

          # Create an IACDoc for the RSDC
          IO.puts(
            "Cloning IacDocument #{iac_doc.id} into RSDC #{rsdc.id}, top_doc_id: #{top_doc_id}, contents #{contents.id}, recipient #{contents.recipient_id}"
          )

          IACDocument.clone_into(iac_doc, :raw_document_customized, rsdc)
        end

        text(conn, "OK")

      "review" ->
        # This is a countersign operation.

        # in this case the assignmentId is actually a contentsId
        contents = Repo.get(PackageContents, assignment_id)

        iaf =
          Repo.get_by(IACAssignedForm, %{
            recipient_id: contents.recipient_id,
            # TODO: do we need this?
            # company_id: company.id,
            master_form_id: iac_doc.master_form_id,
            contents_id: contents.id,
            status: 0
          })

        cs =
          IACAssignedForm.changeset(iaf, %{
            flags: iaf.flags ||| 1
          })

        Repo.update!(cs)

        iaf = Repo.get(IACAssignedForm, iaf.id)
        fields = IACAssignedForm.fields_of(iaf)

        if FunWithFlags.enabled?(:audit_trail_v2) do
          requestor = get_current_requestor(conn)

          BoilerPlateWeb.IACController.esign_create(
            :submit_event,
            iac_doc,
            iaf,
            :requestor,
            requestor,
            ip
          )
        end

        # Create the final document and insert a Document into the database
        # with the final document.
        body =
          BoilerPlateWeb.IACController.make_bp01(
            BoilerPlateWeb.IACController.make_data(fields),
            iac_doc,
            BoilerPlateWeb.IACController.make_audit_trail(iaf, fields, iat, ip)
          )

        # Create a new temporary file
        {:ok, tmp_pdf_path} = Briefly.create(prefix: "boilerplate")
        File.write!(tmp_pdf_path, body)

        # Handoff work
        top_doc_id = IACDocument.base_document_id(iac_doc)

        template_fn = UUID.uuid4() <> ".pdf"

        pa =
          Repo.get_by(PackageAssignment, %{
            contents_id: contents.id,
            recipient_id: contents.recipient_id,
            status: 0
          })

        recipient_upload_document(conn, %{
          "id" => top_doc_id,
          "assignmentId" => pa.id,
          "recipientId" => contents.recipient_id,
          "file" => %{filename: template_fn, path: tmp_pdf_path}
        })
    end
  end

  def iac_submit_fill(conn, %{"id" => iac_doc_id, "assignmentId" => assignment_id}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    assign = Repo.get(PackageAssignment, assignment_id)
    recipient = Repo.get(Recipient, assign.recipient_id)
    iac_doc = Repo.get(IACDocument, iac_doc_id)

    {:ok, claims} =
      BoilerPlate.Guardian.decode_and_verify(BoilerPlate.Guardian.Plug.current_token(conn))

    iat = claims["iat"]
    ip = conn.remote_ip |> Tuple.to_list() |> Enum.join(".")

    case BoilerPlateWeb.IACController.api_submit_iac(
           us_user,
           recipient.id,
           assign.id,
           iac_doc.id,
           iat,
           ip
         ) do
      {:ok, base_doc_id, f_n, path} ->
        recipient_upload_document(conn, %{
          "id" => base_doc_id,
          "assignmentId" => assign.id,
          "recipientId" => recipient.id,
          "file" => %{filename: f_n, path: path}
        })
    end
  end

  def iac_generate_pdf(conn, %{
        "id" => iac_doc_id,
        "contentsId" => contentsId,
        "trueContentsId" => trueContentsId
      }) do
    contents = Repo.get(PackageContents, contentsId)
    true_contents = Repo.get(PackageContents, trueContentsId)
    iac_doc = Repo.get(IACDocument, iac_doc_id)
    recipient = Repo.get(Recipient, contents.recipient_id)
    company = Repo.get(Company, recipient.company_id)
    imf = Repo.get(IACMasterForm, iac_doc.master_form_id)
    requestor = get_current_requestor(conn)

    case BoilerPlateWeb.IACController.api_generate_pdf(
           requestor,
           recipient,
           company,
           iac_doc,
           contents,
           imf,
           true_contents
         ) do
      {:ok, template_fn} ->
        json(conn, %{fn: template_fn})

      err ->
        conn |> put_status(500) |> json(%{error: err})
    end
  end

  def assignment_archive(conn, %{"assignmentId" => aid}) do
    assign = Repo.get(PackageAssignment, aid)

    # audit :assignment_archive, %{user: us_user, recipient_id: recipient.id, package_id: assign.package_id, assignment_id: assign.id, company_id: pkg_company.id}
    if assign != nil do
      cs = PackageAssignment.changeset(assign, %{status: 1})
      Repo.update!(cs)

      BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, assign.recipient_id)
      json(conn, %{status: :ok})
    else
      conn |> put_status(400) |> json(%{error: :invalid_assignment})
    end
  end

  def requestor_assignment_unarchive(conn, %{"assignmentId" => aid}) do
    assign = Repo.get(PackageAssignment, aid)

    requestor = get_current_requestor(conn)

    # audit :assignment_archive, %{user: us_user, recipient_id: recipient.id, package_id: assign.package_id, assignment_id: assign.id, company_id: pkg_company.id}
    if assign != nil and requestor.id == assign.requestor_id do
      cs = PackageAssignment.changeset(assign, %{status: 0})
      Repo.update!(cs)

      BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, assign.recipient_id)
      json(conn, %{status: :ok})
    else
      conn |> put_status(400) |> json(%{error: :invalid_assignment})
    end
  end

  def assignment_unsend(conn, %{"assignmentId" => aid}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    requestor = get_current_requestor(conn)
    assign = Repo.get(PackageAssignment, aid)

    case BoilerPlateWeb.PackageController.api_delete_assignment(
           requestor,
           us_user,
           assign.recipient_id,
           assign.id
         ) do
      :ok ->
        BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, assign.recipient_id)
        json(conn, %{status: :ok})

      :forbidden ->
        conn |> put_status(400) |> json(%{error: :forbidden})
    end
  end

  def recipient_all_assignments_unsend(conn, %{"id" => rid}) do
    recipient = Repo.get(Recipient, rid)

    requestor = get_current_requestor(conn)

    if recipient.company_id == requestor.company_id do
      Repo.all(
        from p in PackageAssignment,
          where:
            p.status != 2 and p.recipient_id == ^recipient.id and
              p.requestor_id == ^requestor.id and p.company_id == ^requestor.company_id,
          select: p
      )
      |> Enum.each(fn assignmt ->
        BoilerPlate.FileCleanerUtils.delete_assignment_files(assignmt.id)
      end)

      text(conn, :ok)
    else
      conn |> put_status(403) |> text(:forbidden)
    end
  end

  def archived_assignments(conn, %{"recipientId" => rid}) do
    recipient = Repo.get(Recipient, rid)

    data = do_make_assignments_of(User.archived_assignments_of(recipient), recipient)
    json(conn, data)
  end

  def user_adhoc_register(conn, %{
        "name" => name,
        "email" => email,
        "organization" => org,
        "hashedPassword" => hashed_password,
        "adhocString" => adhoc_string
      }) do
    adhoc = Repo.get_by(AdhocLink, %{adhoc_string: adhoc_string})
    # TODO: assumed that the adhoc link is of package type
    package = Repo.get(Package, adhoc.type_id)
    pkg_company = Repo.get(Company, package.company_id)

    # The User does not exist, yet, so let's create it.
    new = %User{
      name: name,
      email: String.downcase(email),
      company_id: pkg_company.id,
      organization: org,
      admin_of: nil,
      access_code: "null",
      username: "null",
      verified: true,
      verification_code: User.new_password(16),
      flags: 0,
      password_hash: hashed_password,
      current_document_index: 0
    }

    n = Repo.insert!(new)

    ra =
      Repo.insert!(%Recipient{
        company_id: pkg_company.id,
        name: name,
        organization: org,
        status: 0,
        terms_accepted: false,
        user_id: n.id
      })

    pa = %PackageAssignment{
      company_id: pkg_company.id,
      flags: 0,
      status: 0,
      package_id: package.id,
      contents_id: PackageContents.from_package(ra, package).id,
      recipient_id: ra.id,
      requestor_id: adhoc.requestor_id,
      append_note: "",
      docs_downloaded: []
    }

    Repo.insert!(pa)

    conn =
      conn
      |> BoilerPlate.Guardian.Plug.sign_in(n, %{}, ttl: {720, :minute})

    json(conn, %{status: :ok, new_token: BoilerPlate.Guardian.Plug.current_token(conn)})
  end

  def user_adhoc_assign(conn, %{"id" => id, "name" => name, "adhocString" => adhoc_string}) do
    adhoc = Repo.get_by(AdhocLink, %{adhoc_string: adhoc_string})
    # TODO: assumed that the adhoc link is of package type
    package = Repo.get(Package, adhoc.type_id)
    pkg_company = Repo.get(Company, package.company_id)
    user = Repo.get(User, id)

    recipient =
      Repo.one(
        from r in Recipient,
          where: r.company_id == ^pkg_company.id and r.status == 0 and r.user_id == ^user.id,
          select: r
      )

    if recipient != nil do
      # Check if the recipient has any related assignments
      assignment =
        Repo.one(
          from pa in PackageAssignment,
            where:
              pa.package_id == ^package.id and pa.status == 0 and
                pa.recipient_id == ^recipient.id,
            select: pa,
            limit: 1
        )

      if assignment != nil do
        # Already assigned, redirect user to login.
        # TODO: display some guidance
        json(conn, %{status: :ok})
      else
        # The recipient and user exist - assign the package and forward them to login.
        pa = %PackageAssignment{
          company_id: pkg_company.id,
          flags: 0,
          status: 0,
          package_id: package.id,
          contents_id: PackageContents.from_package(recipient, package).id,
          recipient_id: recipient.id,
          requestor_id: adhoc.requestor_id,
          enforce_due_date: package.enforce_due_date,
          due_date: get_assignment_due_date(package),
          append_note: "",
          docs_downloaded: []
        }

        pa = Repo.insert!(pa)

        # Assignment complete - send them to login
        # TODO: display some guidance
        BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, pa.recipient_id)
        json(conn, %{status: :ok})
      end
    else
      # The user exists, but there is no recipient record yet.
      ra =
        Repo.insert!(%Recipient{
          company_id: pkg_company.id,
          name: name,
          organization: pkg_company.name,
          status: 0,
          terms_accepted: false,
          user_id: user.id
        })

      # Now there is a recipient for the user, add the assignment to it.
      pa = %PackageAssignment{
        company_id: pkg_company.id,
        flags: 0,
        status: 0,
        package_id: package.id,
        contents_id: PackageContents.from_package(ra, package).id,
        recipient_id: ra.id,
        requestor_id: adhoc.requestor_id,
        enforce_due_date: package.enforce_due_date,
        due_date: get_assignment_due_date(package),
        append_note: "",
        docs_downloaded: []
      }

      pa = Repo.insert!(pa)

      # All done.
      # TODO: display some guidance
      BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, pa.recipient_id)
      json(conn, %{status: :ok})
    end
  end

  def adhoc_details(conn, %{"string" => adhoc_string}) do
    adhoc = Repo.get_by(AdhocLink, %{adhoc_string: adhoc_string})
    package = Repo.get(Package, adhoc.type_id)

    json(conn, %{
      title: package.title
    })
  end

  defp update_assignment_reminder_info(assignment, us_user, current_datetime) do
    cs =
      PackageAssignment.changeset(assignment, %{
        reminder_state: %{
          send_by: us_user.name,
          total_count: assignment.reminder_state["total_count"] + 1,
          last_send_at: current_datetime
        }
      })

    Repo.update!(cs)
  end

  def remind_now(conn, %{
        "checklistId" => pid,
        "recipientId" => rid,
        "remindMessage" => remind_now_input
      }) do
    recipient = Repo.get(Recipient, rid)
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    company = Repo.get(Company, recipient.company_id)
    recipient_user = Repo.get(User, recipient.user_id)
    requestor = get_current_requestor(conn)

    cond do
      recipient.company_id != requestor.company_id ->
        conn |> put_status(403) |> text("Forbidden")

      pid == "ALL" ->
        assignments =
          Repo.all(
            from pa in PackageAssignment,
              where: pa.status == 0 and pa.recipient_id == ^rid,
              select: pa
          )

        if assignments != nil do
          Email.send_remind_now_list_email(
            recipient,
            requestor,
            us_user,
            assignments,
            company,
            recipient_user,
            remind_now_input
          )

          current_datetime = BoilerPlate.CustomDateTimex.get_datetime()

          assignments
          |> Enum.each(fn assignment ->
            update_assignment_reminder_info(assignment, us_user, current_datetime)
          end)

          BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, recipient.id)

          json(conn, %{status: :ok})
        else
          conn |> put_status(400) |> json(%{error: :invalid_assignment})
        end

      true ->
        package = Repo.get(Package, pid)

        # Send the singular email
        if package != nil do
          Email.send_remind_now_email(
            recipient,
            us_user,
            package,
            company,
            recipient_user,
            remind_now_input
          )

          json(conn, %{status: :ok})
        else
          conn |> put_status(400) |> json(%{error: :invalid_assignment})
        end
    end
  end

  def remind_now_checklist_v2(conn, %{
        "checklistId" => assignment_id,
        "recipientId" => rid,
        "remindMessage" => remind_now_input
      }) do
    if assignment_id == "ALL" do
      remind_now(conn, %{
        "checklistId" => assignment_id,
        "recipientId" => rid,
        "remindMessage" => remind_now_input
      })
    else
      us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

      company = get_current_requestor(conn, as: :company)
      recipient = Repo.get(Recipient, rid)
      recipient_user = Repo.get(User, recipient.user_id)

      assignment = Repo.get(PackageAssignment, assignment_id)
      package_contents = Repo.get(PackageContents, assignment.contents_id)

      # Send the singular email
      if recipient != nil and company != nil and recipient.company_id == company.id and
           assignment != nil and assignment.recipient_id == recipient.id do
        Email.send_remind_now_email(
          recipient,
          us_user,
          package_contents,
          company,
          recipient_user,
          remind_now_input
        )

        # update last reminder info for assignment
        current_datetime = BoilerPlate.CustomDateTimex.get_datetime()
        update_assignment_reminder_info(assignment, us_user, current_datetime)

        BoilerPlate.DashboardCache.invalidate_recipient(:dashboard_cache, recipient.id)

        json(conn, %{status: :ok})
      else
        conn |> put_status(400) |> json(%{error: :invalid_assignment})
      end
    end
  end

  def get_features(conn, _params) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    if us_user != nil do
      company = Repo.get(Company, us_user.company_id)

      all_enabled_flags =
        FunWithFlags.all_flag_names()
        |> elem(1)
        |> Enum.filter(fn flag ->
          FunWithFlags.enabled?(flag, for: us_user) and FunWithFlags.enabled?(flag, for: company)
        end)

      json(conn, %{
        enabled_flags: all_enabled_flags
      })
    else
      # Grab default feature flags
      all_enabled_flags =
        FunWithFlags.all_flag_names()
        |> elem(1)
        |> Enum.filter(&FunWithFlags.enabled?/1)

      json(conn, %{
        enabled_flags: all_enabled_flags
      })
    end
  end

  def document_proxy(conn, params) do
    file_name = params["filename"] || ""
    disp_name = params["dispName"]
    print = params["print"] || false
    bucket = Application.get_env(:boilerplate, :s3_bucket)

    body = @storage_mod.download_file_stream(bucket, "uploads/#{file_name}")

    extname = Path.extname(file_name)

    conn
    |> put_resp_header("access-control-expose-headers", "*")
    |> put_resp_header(
      "content-disposition",
      if print == false do
        "attachment; filename=\"#{disp_name}#{extname}\""
      else
        "inline;"
      end
    )
    |> put_resp_header("x-boilerplate-filename", "file#{extname}")
    |> resp(200, body)
  end

  def is_assigned_raw_doc_iac_type(rd, assignment_id) do
    assignment = Repo.get(PackageAssignment, assignment_id)

    is_rspec? = RawDocument.is_rspec?(rd)

    rdc =
      if is_rspec? do
        Repo.one(
          from r in RawDocumentCustomized,
            where:
              r.contents_id == ^assignment.contents_id and
                r.recipient_id == ^assignment.recipient_id and
                r.raw_document_id == ^rd.id,
            order_by: [desc: r.inserted_at],
            limit: 1,
            select: r
        )
      else
        nil
      end

    if is_rspec? and iac_setup_for_customization?(rd, rdc) do
      IACDocument.get_for(:raw_document_customized, rdc)
    else
      IACDocument.get_for(:raw_document, rd)
    end
  end

  def get_completion(conn, %{"did" => did, "type" => "1"}) do
    comp = Repo.get(Document, did)
    rd = Repo.get(RawDocument, comp.raw_document_id)

    iac_doc = is_assigned_raw_doc_iac_type(rd, comp.assignment_id)

    json(conn, %{
      filename: comp.filename,
      recipient_id: comp.recipient_id,
      name: rd.name,
      description: rd.description,
      submitted: comp.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D} {0h12}:{0m}:{0s} {AM}"),
      flags: comp.flags,
      status: comp.status,
      is_iac: iac_doc != nil,
      iac_doc_id:
        if iac_doc != nil do
          iac_doc.id
        else
          nil
        end
    })
  end

  def get_completion(conn, %{"did" => did, "type" => "2"}) do
    comp = Repo.get(RequestCompletion, did)
    rd = Repo.get(DocumentRequest, comp.requestid)

    json(conn, %{
      filename: comp.file_name,
      recipient_id: comp.recipientid,
      name: rd.title,
      request_id: rd.id,
      status: comp.status,
      description: rd.description,
      type:
        if 2 in rd.attributes do
          "data"
        else
          if 1 in rd.attributes do
            "task"
          else
            "file"
          end
        end,
      file_request_reference: comp.file_request_reference,
      submitted: comp.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D} {0h12}:{0m}:{0s} {AM}"),
      is_enabled_tracking: rd.enable_expiration_tracking,
      doc_expiration_info: rd.expiration_info
    })
  end

  def get_completion(conn, %{"did" => did, "type" => "3"}) do
    requestor = get_current_requestor(conn)
    comp = Repo.get(Cabinet, did)
    recipient = Repo.get(Recipient, comp.recipient_id)

    if requestor != nil and recipient != nil and requestor.company_id == recipient.company_id do
      json(conn, %{
        filename: comp.filename,
        recipient_id: comp.recipient_id,
        name: comp.name,
        description: "",
        submitted: comp.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D} {0h12}:{0m}:{0s} {AM}")
      })
    else
      conn |> put_status(403) |> text("Forbidden")
    end
  end

  def whitelabel_info(conn, params) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    if us_user == nil do
      json(conn, %{
        enabled: true,
        logo_url: ""
      })
    else
      user_type = params["user_type"] || "recipient"
      recipient = get_current_recipient(conn)
      requestor = get_current_requestor(conn)

      cond do
        user_type == "requestor" and requestor == nil ->
          json(conn, %{
            enabled: false,
            logo_url: ""
          })

        user_type == "requestor" ->
          company = Repo.get(Company, requestor.company_id)

          json(conn, %{
            enabled: company.whitelabel_enabled,
            logo_url: "/n/api/v1/dproxy/#{company.whitelabel_image_name}"
          })

        user_type == "recipient" and recipient == nil ->
          json(conn, %{
            enabled: false,
            logo_url: ""
          })

        user_type == "recipient" ->
          company = Repo.get(Company, recipient.company_id)

          json(conn, %{
            enabled: company.whitelabel_enabled,
            logo_url: "/n/api/v1/dproxy/#{company.whitelabel_image_name}"
          })

        True ->
          json(conn, %{
            enabled: false
          })
      end
    end
  end

  def user_forgot_password(conn, %{"email" => email}) do
    BoilerPlateWeb.UserController.api_do_forgot_password(email)
    json(conn, %{status: :ok})
  end

  def filter_rsd_doc?(rd, cid, rid) do
    if RawDocument.is_rspec?(rd) && !RawDocument.is_info?(rd) do
      Repo.aggregate(
        from(r in RawDocumentCustomized,
          where:
            r.contents_id == ^cid and r.recipient_id == ^rid and
              r.raw_document_id == ^rd.id,
          order_by: [desc: r.inserted_at],
          limit: 1,
          select: r
        ),
        :count,
        :id
      ) > 0
    else
      false
    end
  end

  def iac_get_prefilled(conn, %{"rid" => rid, "cid" => cid}) do
    contents = Repo.get(PackageContents, cid)
    recipient = Repo.get(Recipient, rid)
    company = Repo.get(Company, recipient.company_id)

    json(
      conn,
      contents.documents
      |> Enum.map(&Repo.get(RawDocument, &1))
      |> Enum.filter(fn x -> filter_rsd_doc?(x, cid, rid) end)
      |> Enum.map(&IACDocument.get_for(:raw_document, &1))
      |> Enum.filter(&(&1 != nil))
      |> Enum.map(
        &{&1,
         BoilerPlateWeb.IACController.get_iaf_for_ifexists(
           recipient,
           company,
           &1,
           contents,
           Repo.get(IACMasterForm, &1.master_form_id)
         )}
      )
      |> Enum.map(fn {d, a} -> {d.document_id, a.flags == 1} end)
      |> Enum.filter(fn {_, x} -> x == true end)
      |> Enum.map(fn {a, _} -> a end)
    )
  end

  def get_iac_prefilled_doc(conn, params = %{"id" => raw_doc_customization_id}) do
    requestor = get_current_requestor(conn)
    assignment_id = params["assignmentId"]

    requestor_company = Repo.get(Company, requestor.company_id)

    rspec_doc = Repo.get(RawDocumentCustomized, raw_doc_customization_id)
    rd = Repo.get(RawDocument, rspec_doc.raw_document_id)

    iac_doc =
      if assignment_id != nil do
        is_assigned_raw_doc_iac_type(rd, params["assignmentId"])
      else
        nil
      end

    if rd.company_id == requestor_company.id do
      json(conn, %{
        filename: rspec_doc.file_name,
        recipient_id: rspec_doc.recipient_id,
        name: rd.name,
        description: rd.description,
        contents_id: rspec_doc.contents_id,
        iac_doc_id: if(iac_doc != nil, do: iac_doc.id),
        submitted:
          rspec_doc.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D} {0h12}:{0m}:{0s} {AM}")
      })
    else
      conn |> put_status(403) |> text(:forbidden)
    end
  end

  def user_set_password(conn, %{"current_lhash" => _clh, "uid" => uid, "new_lhash" => nlh}) do
    user = Repo.get(User, uid)

    if (user.flags &&& 2) == 0 do
      cs =
        User.changeset(user, %{
          password_hash: nlh,
          flags: user.flags ||| 2,
          logins_count: user.logins_count + 1
        })

      Repo.update!(cs)

      is_admin? =
        Repo.aggregate(
          from(r in Requestor, where: r.user_id == ^user.id and r.status == 0, select: r),
          :count,
          :id
        ) > 0

      conn
      |> BoilerPlate.Guardian.Plug.sign_in(user, %{blptreq: is_admin?}, ttl: {720, :minute})
      |> json(%{status: :ok})
    else
      conn |> put_status(400) |> text("bad hash")
    end
  end

  def do_delivery_fault(conn, %{
        "pa_id" => pa_id,
        "fault" => fault,
        "fault_message" => fault_message,
        "to_email" => to_email,
        "secret" => secret
      }) do
    BoilerPlate.EmailDeliveryChecker.delivery_fault(pa_id, fault, fault_message, to_email, secret)

    text(conn, "OK")
  end

  def do_clear_delivery_fault(conn, %{"user_id" => user_id, "secret" => secret}) do
    BoilerPlate.EmailDeliveryChecker.clear_delivery_fault(user_id, secret)

    text(conn, "OK")
  end

  def do_weekly_digest_debug_test(conn, %{"user_id" => user_id}) do
    user_id =
      if user_id == 0 do
        get_current_requestor(conn).id
      else
        user_id
      end

    conn
    |> json(WeeklyStatusChecker.create_weekly_status(user_id))
  end
end
