alias BoilerPlate.PaymentCoupon
alias BoilerPlate.PaymentPlan
alias BoilerPlate.Repo
alias BoilerPlate.RawDocument
alias BoilerPlate.IACDocument
alias BoilerPlate.IACMasterForm
alias BoilerPlate.IACField
alias BoilerPlate.User
alias BoilerPlate.Requestor
alias BoilerPlate.Company
import Ecto.Query
import Bitwise

defmodule BoilerPlateWeb.InternalController do
  use BoilerPlateWeb, :controller

  def instance_admins() do
    [
      "lk@cetlie.hu",
      "lev@boilerplate.co",
      "brian@boilerplate.co",
      "bmagrann@gmail.com",
      "basic1@cetlie.hu",
      "tripp@boilerplate.co",
      "demo@boilerplate.co",
      "rishi@boilerplate.co",
      "saiful@boilerplate.co",
      "umair@boilerplate.co",
      "prem@boilerplate.co",
      "nandi@boilerplate.co"
    ]
  end

  def impersonation_list() do
    [
      "lk@cetlie.hu",
      "lev@boilerplate.co",
      "brian@boilerplate.co",
      "bmagrann@gmail.com"
    ]
  end

  def stats_summarize_metrics(data) do
    Enum.reduce(data, %{}, fn {_, v}, acc ->
      Map.new(
        for {ak, av} <- v do
          if Map.has_key?(acc, ak) do
            {ak, acc[ak] + av}
          else
            {ak, av}
          end
        end
      )
    end)
  end

  def show_statistics(conn, _params) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    if us_user.email in instance_admins() do
      companies_to_interrogate =
        Repo.all(from c in Company, where: c.status == 2, select: c)
        |> Enum.filter(&((&1.flags &&& 4) == 4))

      billing_metrics =
        for company <- companies_to_interrogate do
          utc_time_today = BoilerPlate.CustomDateTimex.get_datetime()
          all_associated_user_ids = User.all_associated_with(company) |> Enum.map(& &1.id)
          company_id = company.id

          data = [
            {"week",
             BoilerPlateWeb.BillingMetrics.calculate_billing_metrics(
               :week,
               company_id,
               all_associated_user_ids,
               utc_time_today
             )},
            {"current_month",
             BoilerPlateWeb.BillingMetrics.calculate_billing_metrics(
               :current_month,
               company_id,
               all_associated_user_ids,
               utc_time_today
             )},
            {"current_year",
             BoilerPlateWeb.BillingMetrics.calculate_billing_metrics(
               :current_year,
               company_id,
               all_associated_user_ids,
               utc_time_today
             )},
            {"last_month",
             BoilerPlateWeb.BillingMetrics.calculate_billing_metrics(
               :last_month,
               company_id,
               all_associated_user_ids,
               utc_time_today
             )},
            {"current_quarter",
             BoilerPlateWeb.BillingMetrics.calculate_billing_metrics(
               :current_quarter,
               company_id,
               all_associated_user_ids,
               utc_time_today
             )},
            {"last_quarter",
             BoilerPlateWeb.BillingMetrics.calculate_billing_metrics(
               :last_quarter,
               company_id,
               all_associated_user_ids,
               utc_time_today
             )},
            {"lifetime",
             BoilerPlateWeb.BillingMetrics.calculate_billing_metrics(
               :lifetime,
               company_id,
               all_associated_user_ids,
               utc_time_today
             )}
          ]

          %{
            company: company,
            metrics: data,
            totals:
              data
              |> stats_summarize_metrics()
          }
        end

      if billing_metrics != [] do
        render(conn, "instance_stats.html", billing_data: billing_metrics)
      else
        text(conn, "No companies to calculate stats for")
      end
    else
      text(conn, "Access denied")
    end
  end

  def instance_new_notification(conn, %{"title" => n_title, "message" => n_msg}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    if us_user.email in instance_admins() do
      all_impersonate_companies =
        Repo.all(from c in Company, where: c.status == 2, select: c)
        |> Enum.filter(fn c -> (c.flags &&& 4) == 4 end)

      BoilerPlateWeb.NotificationController.add_internal_notification_to_companies(
        all_impersonate_companies,
        n_msg,
        n_title
      )

      conn |> text("OK, sent")
    else
      conn |> put_status(403) |> text("Forbidden")
    end
  end

  def instance_admin(conn, _params) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    if us_user.email in instance_admins() do
      render(conn, "instance_admin.html")
    else
      text(conn, "Access denied")
    end
  end

  def internal_do_template_mover(conn, %{
        "template" => rdId,
        "company" => companyId,
        "action" => "copy"
      }) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    if us_user.email in instance_admins() do
      rd = Repo.get(RawDocument, rdId)
      target = Repo.get(Company, companyId)

      nrd =
        Repo.insert!(%RawDocument{
          description: rd.description,
          file_name: rd.file_name,
          name: rd.name,
          company_id: target.id,
          type: rd.type,
          flags: rd.flags,
          iac_master_id: rd.iac_master_id,
          editable_during_review: rd.editable_during_review,
          is_archived: rd.is_archived
        })

      iac_doc = IACDocument.get_for(:raw_document, rd)
      iamf = Repo.get(IACMasterForm, iac_doc.master_form_id)
      fields = IACMasterForm.fields_of(iac_doc)
      # Copy the master form
      new_iamf =
        Repo.insert!(%IACMasterForm{
          company_id: target.id,
          creator_id: iamf.creator_id,
          fields: [],
          base_pdf: iamf.base_pdf,
          name: iamf.name,
          description: iamf.description,
          status: iamf.status,
          flags: iamf.flags
        })

      # Create the new fields
      new_fields =
        fields
        |> Enum.map(
          &Repo.insert!(%IACField{
            parent_id: new_iamf.id,
            parent_type: &1.parent_type,
            name: &1.name,
            location_type: &1.location_type,
            location_value_1: &1.location_value_1,
            location_value_2: &1.location_value_2,
            location_value_3: &1.location_value_3,
            location_value_4: &1.location_value_4,
            location_value_5: &1.location_value_5,
            location_value_6: &1.location_value_6,
            field_type: &1.field_type,
            master_field_id: &1.master_field_id,
            set_value: &1.set_value,
            default_value: &1.default_value,
            internal_value_1: &1.internal_value_1,
            fill_type: &1.fill_type,
            status: &1.status,
            label: &1.label,
            label_value: &1.label_value,
            label_question: &1.label_question,
            label_question_type: &1.label_question_type,
            repeat_entry_form_id: &1.repeat_entry_form_id,
            label_id: &1.label_id,
            flags: &1.flags
          })
        )

      # Add the fields
      Repo.update!(IACMasterForm.changeset(new_iamf, %{fields: new_fields |> Enum.map(& &1.id)}))

      # Now copy the IAC document
      Repo.insert!(%IACDocument{
        document_type: iac_doc.document_type,
        document_id: nrd.id,
        file_name: iac_doc.file_name,
        master_form_id: new_iamf.id,
        contents_id: iac_doc.contents_id,
        recipient_id: iac_doc.recipient_id,
        raw_document_id: iac_doc.raw_document_id,
        status: iac_doc.status,
        flags: iac_doc.flags
      })

      redirect(conn, to: "/internal/tmplmover")
    else
      text(conn, "Access denied")
    end
  end

  def internal_do_template_mover(conn, %{
        "template" => rdId,
        "company" => companyId,
        "action" => "move"
      }) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    if us_user.email in instance_admins() do
      rd = Repo.get(RawDocument, rdId)
      target = Repo.get(Company, companyId)

      cs = RawDocument.changeset(rd, %{company_id: target.id})
      Repo.update!(cs)

      redirect(conn, to: "/internal/tmplmover")
    else
      text(conn, "Access denied")
    end
  end

  def internal_template_mover(conn, _params) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    if us_user.email in instance_admins() do
      all_abby_templates =
        Repo.all(
          from r in RawDocument,
            where: r.company_id == 571 and r.is_archived == false,
            select: r,
            order_by: [desc: r.inserted_at]
        )
        |> Enum.filter(fn r -> RawDocument.is_hidden?(r) == false end)

      all_impersonate_companies =
        Repo.all(from c in Company, where: c.status == 2, select: c, order_by: [asc: c.name])
        |> Enum.filter(fn c -> (c.flags &&& 4) == 4 end)

      render(conn, "instance_tmplmover.html",
        all_abby_templates: all_abby_templates,
        all_impersonate_companies: all_impersonate_companies
      )
    else
      text(conn, "Access denied")
    end
  end

  def instance_newcoupon(conn, %{"name" => name, "type" => type, "val" => value}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    if us_user.email in instance_admins() do
      {type_i, _} = Integer.parse(type)
      name = String.trim(String.downcase(name))

      pc = %PaymentCoupon{
        status: 0,
        flags: 0,
        type: type_i,
        value: value,
        name: name
      }

      Repo.insert!(pc)

      redirect(conn, to: "/internal/admin")
    else
      text(conn, "Access denied")
    end
  end

  def instance_newpaymentplan(conn, %{
        "name" => name,
        "display_name" => display_name,
        "cost" => base_cost,
        "charge_frequency" => charge_frequency,
        "seats" => seats
      }) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    pp_pre = Repo.get_by(PaymentPlan, %{name: name})

    cond do
      pp_pre != nil ->
        text(conn, "PaymentPlan name not unique")

      us_user.email in instance_admins() ->
        {cost_i, _} = Integer.parse(base_cost)
        {cf_i, _} = Integer.parse(charge_frequency)
        {seats_i, _} = Integer.parse(seats)
        name = String.trim(String.downcase(name))

        pc = %PaymentPlan{
          status: 0,
          flags: 0,
          name: name,
          seats: seats_i,
          display_name: display_name,
          base_cost: cost_i,
          charge_frequency: cf_i
        }

        Repo.insert!(pc)

        redirect(conn, to: "/internal/admin")

      True ->
        text(conn, "Access denied")
    end
  end

  def instance_company_mandate_mfa(conn, %{"cid" => cid}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    company = Repo.get(Company, cid)

    if us_user.email in instance_admins() do
      cs = Company.changeset(company, %{mfa_mandate: not company.mfa_mandate})
      Repo.update!(cs)

      redirect(conn, to: "/internal/admin")
    else
      text(conn, "Access denied")
    end
  end

  def instance_company_expire_trial(conn, %{"cid" => cid}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    company = Repo.get(Company, cid)

    if us_user.email in instance_admins() do
      cs = Company.changeset(company, %{trial_end: Date.utc_today() |> Date.add(-1)})
      Repo.update!(cs)

      send(:bp_payments, :check_trials)

      redirect(conn, to: "/internal/admin")
    else
      text(conn, "Access denied")
    end
  end

  def instance_new_co(conn, _params) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    if us_user.email in instance_admins() do
      render(conn, "instance_newco.html")
    else
      text(conn, "Access denied")
    end
  end

  def instance_mod_co(conn, _params) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    if us_user.email in instance_admins() do
      render(conn, "instance_modco.html")
    else
      text(conn, "Access denied")
    end
  end

  def instance_users(conn, _params) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    if us_user.email in instance_admins() do
      render(conn, "instance_users.html",
        users: Repo.all(from u in User, select: u, order_by: u.id)
      )
    else
      text(conn, "Access denied")
    end
  end

  def instance_requestors(conn, _params) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    if us_user.email in instance_admins() do
      render(conn, "instance_requests.html",
        requestors:
          Repo.all(
            from u in User,
              join: r in Requestor,
              on: r.user_id == u.id,
              join: c in Company,
              on: c.id == r.company_id,
              where: r.status == 0 or r.status == 1,
              select: %{
                email: u.email,
                name: r.name,
                revoked: r.status == 1,
                user_id: u.id,
                requestor_id: r.id,
                company_name: c.name,
                inserted_at: r.inserted_at
              }
          )
      )
    else
      text(conn, "Access denied")
    end
  end

  def revoke_requestor(conn, %{"reqid" => reqid}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    if us_user.email in instance_admins() do
      requestor = Repo.get(Requestor, reqid)
      company = Repo.get(Company, requestor.company_id)
      user = Repo.get(User, requestor.user_id)
      render(conn, "verify_revoke.html", requestor: requestor, company: company, user: user)
    else
    end
  end

  def do_revoke_requestor(conn, %{"reqid" => reqid}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    if us_user.email in instance_admins() do
      requestor = Repo.get(Requestor, reqid)
      cs = Requestor.changeset(requestor, %{status: 1})
      Repo.update!(cs)
      text(conn, "Revoked access for #{requestor.name} (id #{requestor.id})")
    else
      text(conn, "Access denied")
    end
  end

  def do_reinstate_requestor(conn, %{"reqid" => reqid}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    if us_user.email in instance_admins() do
      requestor = Repo.get(Requestor, reqid)
      cs = Requestor.changeset(requestor, %{status: 0})
      Repo.update!(cs)
      text(conn, "Reinstated  access for #{requestor.name} (id #{requestor.id})")
    else
      text(conn, "Access denied")
    end
  end

  def impersonate_user(conn, %{"iid" => iid, "vcode" => vcode}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    secret = Application.get_env(:boilerplate, :totp_impersonate_secret) |> Base.decode32!()

    if us_user.email in impersonation_list() and
         NimbleTOTP.valid?(secret, vcode) do
      target_user = Repo.get(User, iid)

      is_admin? =
        Repo.aggregate(
          from(r in Requestor, where: r.user_id == ^target_user.id and r.status == 0, select: r),
          :count,
          :id
        ) > 0

      conn
      |> BoilerPlate.Guardian.Plug.sign_out()
      |> BoilerPlate.Guardian.Plug.sign_in(
        target_user,
        %{
          two_factor_approved: true,
          blptreq: is_admin?,
          # Note in the claims that this is an impersonation session.
          blptimp: true
        },
        ttl: {720, :minute}
      )
      |> redirect(to: "/")
    else
      text(conn, "Access denied")
    end
  end

  def force_verify_user(conn, %{"iid" => iid}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    if us_user.email in instance_admins() do
      target = Repo.get(User, iid)

      Repo.update!(User.changeset(target, %{verified: true}))
      redirect(conn, to: "/internal/users")
    else
      text(conn, "Access denied")
    end
  end

  def force_disable_2fa(conn, %{"iid" => iid}) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    if us_user.email in instance_admins() do
      target = Repo.get(User, iid)

      Repo.update!(User.changeset(target, %{two_factor_state: 0}))
      redirect(conn, to: "/internal/users")
    else
      text(conn, "Access denied")
    end
  end

  defp generate_funny_password() do
    fruits = [
      "lemon",
      "lime",
      "blackberry",
      "blueberry",
      "redberry",
      "cocoa",
      "banana",
      "avocado",
      "pomelo",
      "apple",
      "peach",
      "acai",
      "currant",
      "melon",
      "grapefruit",
      "watermelon",
      "plum",
      "orange",
      "papaya",
      "tomato",
      "mulberry"
    ]

    colors = [
      "red",
      "green",
      "blue",
      "gold",
      "silver",
      "orange",
      "light",
      "purple",
      "fuchsia",
      "gray",
      "grey",
      "olive",
      "coral",
      "violet",
      "maroon",
      "cyan"
    ]

    verbs = [
      "very",
      "nicely",
      "big",
      "large",
      "small",
      "huge",
      "cool",
      "quiet",
      "loud",
      "happy",
      "nice",
      "friendly"
    ]

    "#{Enum.random(verbs)}-#{Enum.random(colors)}-#{Enum.random(fruits)}"
  end

  def do_instance_mod_co(conn, %{
        "fn" => name,
        "email" => email,
        "company" => company_id
      }) do
    email = String.trim(String.downcase(email))
    target_company = Repo.get(Company, company_id)
    new_password = generate_funny_password()
    password_hashed = new_password |> User.hash_password()

    if User.exists?(email) do
      user = Repo.get_by(User, %{email: email})

      requestor =
        Repo.get_by(Requestor, %{
          user_id: user.id
        })

      if requestor != nil do
        text(
          conn,
          "User is already a requestor (potentially in another company) and this is not a supported use case right now"
        )
      else
        requestor = %Requestor{
          company_id: target_company.id,
          terms_accepted: true,
          user_id: user.id,
          status: 0,
          name: name,
          organization: target_company.name
        }

        Repo.insert!(requestor)

        BoilerPlate.Email.send_alternate_admin_email(user, new_password)

        text(
          conn,
          "Added a requestor account for existing user. Their password wasn't reset, a welcome email was sent."
        )
      end
    else
      user = %User{
        access_code: "",
        name: name,
        email: String.downcase(email),
        admin_of: target_company.id,
        company_id: target_company.id,
        current_package: 0,
        current_document_index: 0,
        username: email,
        password_hash: password_hashed,
        flags: 0,
        stripe_customer_id: "",
        organization: target_company.name,
        coupon: 0,
        plan: "pro",
        terms_accepted: true,
        verified: true,
        verification_code: "",
        phone_number: "",
        two_factor_state: 0,
        logins_count: 0
      }

      n = Repo.insert!(user)

      requestor = %Requestor{
        company_id: target_company.id,
        terms_accepted: true,
        user_id: n.id,
        status: 0,
        name: name,
        organization: target_company.name
      }

      req = Repo.insert!(requestor)

      BoilerPlate.Email.send_new_admin_email(user, new_password)

      text(
        conn,
        "Added, email sent, their user id #{n.id}, their requestor id #{req.id}, their password is: #{new_password}"
      )
    end
  end

  def do_instance_new_co(conn, %{
        "fn" => name,
        "company_name" => org,
        "email" => email,
        "payment_plan" => pp_name,
        "move_account" => move_account
      }) do
    email = String.trim(String.downcase(email))
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    pp_name = String.split(pp_name, " ") |> Enum.at(0)
    pp = Repo.get_by(PaymentPlan, %{name: pp_name})

    target_pp_name =
      if pp == nil do
        "advanced"
      else
        pp.name
      end

    # #8287: Make all new companies eligible for impersonation
    target_status = 2
    # if pp_name == "free_trial" do
    # 2
    # else
    # 0
    # end

    if User.exists?(email) do
      if move_account == "YES" do
        target_user = Repo.get_by(User, %{email: email})
        requestor = Repo.get_by(Requestor, %{user_id: target_user.id})

        # Check if already a requestor - deny it if so.
        if requestor == nil do
          # Create the new company
          customer = %{
            name: org,
            email: email
          }

          {:ok, stripe_customer} = Stripe.Customer.create(customer)

          company =
            Repo.insert!(%Company{
              name: org,
              stripe_customer_id: stripe_customer.id,
              plan: target_pp_name,
              status: target_status,
              flags: 4,
              coupon: 0,
              trial_end: Date.utc_today() |> Date.add(14),
              trial_max_packages: 0,
              next_payment_due: Date.utc_today() |> Date.add(14)
            })

          # Move the User account to the new company
          Repo.update!(
            User.changeset(target_user, %{admin_of: company.id, company_id: company.id})
          )

          # Insert a Requestor account
          requestor =
            Repo.insert!(%Requestor{
              company_id: company.id,
              terms_accepted: false,
              user_id: target_user.id,
              status: 0,
              name: name,
              organization: org
            })

          target_user = Repo.get(User, target_user.id)

          text(
            conn,
            """
            Moved user to become a requestor at a new company:
            company id: #{company.id}, name: #{company.name}, stripe id: #{company.stripe_customer_id}
            requestor id: #{requestor.id} name: #{requestor.name}
            user admin_of #{target_user.admin_of}, company_id: #{target_user.company_id}
            """
          )
        else
          text(
            conn,
            "This user is already a requestor in another company, refusing to move this account."
          )
        end
      else
        text(
          conn,
          "This user already exists, please choose another email, move_account = #{move_account}"
        )
      end
    else
      if us_user.email in instance_admins() do
        customer = %{
          name: org,
          email: email
        }

        {:ok, stripe_customer} = Stripe.Customer.create(customer)

        company = %Company{
          name: org,
          stripe_customer_id: stripe_customer.id,
          plan: target_pp_name,
          status: target_status,
          flags: 4,
          coupon: 0,
          trial_end: Date.utc_today() |> Date.add(14),
          trial_max_packages: 0,
          next_payment_due: Date.utc_today() |> Date.add(14)
        }

        company = Repo.insert!(company)

        password = User.new_password(16)

        user = %User{
          access_code: "",
          name: name,
          email: String.downcase(email),
          admin_of: company.id,
          company_id: company.id,
          current_package: 0,
          current_document_index: 0,
          verified: true,
          username: "",
          password_hash: password |> User.hash_password(),
          flags: 4,
          stripe_customer_id: nil,
          organization: org,
          coupon: 0,
          plan: target_pp_name,
          terms_accepted: true,
          logins_count: 0
        }

        user = Repo.insert!(user)

        requestor = %Requestor{
          company_id: company.id,
          terms_accepted: true,
          user_id: user.id,
          status: 0,
          name: name,
          organization: org
        }

        Repo.insert!(requestor)

        text(conn, "Account #{user.id} (#{user.name}) created with password: #{password}")
      else
        text(conn, "Access denied")
      end
    end
  end

  @expected_telemetry_key "fde543ea9918024cdc58105cd2c1042db5e2af6ddb6c24c4d46e1ad4de34f0e5"
  def telemetry_dump(conn, %{"key" => telemetry_key}) do
    if telemetry_key != @expected_telemetry_key do
      conn |> put_status(403) |> text("Forbidden")
    else
      ets_data = :ets.tab2list(:boilerplate_stats_plug)

      mapped_data =
        for {k, v} <- ets_data, into: %{} do
          {k, v}
        end

      json(conn, mapped_data)
    end
  end

  def timer_dump(conn, _params) do
    timer_data =
      BoilerPlateAssist.SendAfter.get_timer_data()
      |> Enum.map(fn x ->
        now = Timex.now()
        then = Timex.add(now, Timex.Duration.from_milliseconds(x.time_left))
        Map.put(x, :fire_time, then)
      end)

    render(conn, "instance_timers.html", timers: timer_data)
  end

  def version(conn, _params) do
    git_version = System.cmd("#{File.cwd!()}/tools/get_git_status.sh", []) |> elem(0)
    nomad_allocation_id = System.get_env("NOMAD_ALLOC_ID", "not_in_nomad")
    nomad_image = System.get_env("BOILERPLATE_IMAGE_HASH", "not_in_nomad")
    elixir_version = System.version()
    erlang_version = :erlang.system_info(:version)
    otp_version = :erlang.system_info(:otp_release)

    conn
    |> text(
      "app: #{Application.get_env(:boilerplate, :version)}\napi: 0.0.0\ngit: #{git_version}\nnomad: #{nomad_allocation_id}\ntag=#{nomad_image}\nelixir=#{elixir_version}+Erlang/#{erlang_version}/OTP#{otp_version}"
    )
  end

  def test_crash(_conn, _params) do
    raise ArgumentError, message: "Test Crash"
  end

  def test_dump_session(conn, _params) do
    session_id = Plug.Conn.get_session(conn, :session_id)
    {:ok, {:ok, log}} = BoilerPlate.DashboardCache.get_session_log(:dashboard_cache, session_id)

    json(conn, log |> Enum.map(fn x -> Jason.decode!(x) end))
  end
end
