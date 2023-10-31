# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     BoilerPlate.Repo.insert!(%BoilerPlate.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
#
alias BoilerPlate.Repo
alias BoilerPlate.Company
alias BoilerPlate.User
alias BoilerPlate.Recipient
alias BoilerPlate.Requestor
alias BoilerPlate.RawDocument
alias BoilerPlate.Package
alias BoilerPlate.IACLabel

if System.get_env("BOILERPLATE_NOMAD") == "1" do
  Code.eval_file("priv/repo/seeds_nomad.exs")
  Code.eval_file("priv/repo/seeds_nomad_extra.exs")
else
  #
  # Companies
  #

  acme =
    Repo.insert!(%Company{
      name: "ACME Corp.",
      stripe_customer_id: nil,
      plan: "pro",
      coupon: 0,
      trial_end: nil,
      trial_max_packages: nil,
      next_payment_due: nil,
      status: 2,
      flags: 0
    })

  bp =
    Repo.insert!(%Company{
      name: "Boilerplate, Inc.",
      stripe_customer_id: nil,
      plan: "pro",
      coupon: 0,
      trial_end: nil,
      trial_max_packages: nil,
      next_payment_due: nil,
      status: 2,
      flags: 0
    })

  justin_co =
    Repo.insert!(%Company{
      name: "Sample Company, Inc.",
      stripe_customer_id: nil,
      plan: "pro",
      coupon: 0,
      trial_end: nil,
      trial_max_packages: nil,
      next_payment_due: nil,
      status: 2,
      flags: 0
    })

  tripp_co =
    Repo.insert!(%Company{
      name: "Tripp Company, Inc.",
      stripe_customer_id: nil,
      plan: "pro",
      coupon: 0,
      trial_end: nil,
      trial_max_packages: nil,
      next_payment_due: nil,
      status: 2,
      flags: 0
    })

  keith_co =
    Repo.insert!(%Company{
      name: "Keith Company, Inc.",
      stripe_customer_id: nil,
      plan: "pro",
      coupon: 0,
      trial_end: nil,
      trial_max_packages: nil,
      next_payment_due: nil,
      status: 2,
      flags: 0
    })

  #
  # Raw Documents (aka, templates)
  #

  swe_contract =
    Repo.insert!(%RawDocument{
      name: "Contractor Agreement",
      description: "Simple SWE Contractor Agreement",
      file_name: "0c4a8580-dfa7-4a10-9e11-0cbe40841dc4.pdf",
      company_id: acme.id,
      type: 0,
      flags: 0
    })

  bill_of_sale =
    Repo.insert!(%RawDocument{
      name: "Bill of Sale",
      description: "IAC Demo",
      file_name: "a4d80558-d180-47f8-90b6-82409385403f.pdf",
      company_id: acme.id,
      type: 0,
      flags: 0
    })

  #
  # Packages
  #

  swe =
    Repo.insert!(%Package{
      title: "Software Engineer",
      description: "Standard documents required for a SWE",
      status: 0,
      templates: [swe_contract.id],
      company_id: acme.id
    })

  #
  # Users
  #
  #
  lev =
    Repo.insert!(%User{
      name: "Levente Kurusa",
      access_code: nil,
      password_hash: "a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3",
      email: "lk@cetlie.hu",
      current_package: nil,
      admin_of: acme.id,
      company_id: acme.id,
      current_document_index: 0,
      verified: true,
      username: nil,
      coupon: 0,
      plan: "time_saver",
      flags: 0,
      organization: "ACME",
      terms_accepted: true,
      stripe_customer_id: nil
    })

  Repo.insert!(%Requestor{
    user_id: lev.id,
    company_id: acme.id,
    name: lev.name,
    status: 0,
    organization: lev.organization,
    terms_accepted: true
  })

  brian =
    Repo.insert!(%User{
      name: "Brian P. Magrann",
      access_code: nil,
      password_hash: "a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3",
      email: "bmagrann@gmail.com",
      current_package: nil,
      admin_of: bp.id,
      company_id: bp.id,
      current_document_index: 0,
      verified: true,
      username: nil,
      coupon: 0,
      plan: "time_saver",
      flags: 0,
      organization: "Boilerplate",
      terms_accepted: true,
      stripe_customer_id: nil
    })

  Repo.insert!(%Requestor{
    user_id: brian.id,
    company_id: bp.id,
    name: brian.name,
    organization: brian.organization,
    status: 0,
    terms_accepted: true
  })

  justin =
    Repo.insert!(%User{
      name: "Justin Korman",
      access_code: nil,
      password_hash: "a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3",
      email: "justin@boilerplate.co",
      current_package: nil,
      admin_of: justin_co.id,
      company_id: justin_co.id,
      current_document_index: 0,
      username: nil,
      verified: true,
      coupon: 0,
      plan: "pro",
      flags: 0,
      organization: "Boilerplate, Inc.",
      terms_accepted: true,
      stripe_customer_id: nil
    })

  Repo.insert!(%Requestor{
    user_id: justin.id,
    company_id: justin_co.id,
    name: justin.name,
    organization: justin.organization,
    status: 0,
    terms_accepted: true
  })

  tripp =
    Repo.insert!(%User{
      name: "Tripp Sautner",
      access_code: nil,
      password_hash: "a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3",
      email: "tripp@boilerplate.co",
      current_package: nil,
      admin_of: tripp_co.id,
      company_id: tripp_co.id,
      current_document_index: 0,
      username: nil,
      verified: true,
      coupon: 0,
      plan: "pro",
      flags: 0,
      organization: "Boilerplate, Inc.",
      terms_accepted: true,
      stripe_customer_id: nil
    })

  Repo.insert!(%Requestor{
    user_id: tripp.id,
    company_id: tripp_co.id,
    name: tripp.name,
    organization: tripp.organization,
    status: 0,
    terms_accepted: true
  })

  keith =
    Repo.insert!(%User{
      name: "Keith Carlins",
      access_code: nil,
      password_hash: "a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3",
      email: "keith@boilerplate.co",
      current_package: nil,
      admin_of: keith_co.id,
      company_id: keith_co.id,
      current_document_index: 0,
      username: nil,
      verified: true,
      coupon: 0,
      plan: "pro",
      flags: 0,
      organization: "Keith Company, Inc.",
      terms_accepted: true,
      stripe_customer_id: nil
    })

  Repo.insert!(%Requestor{
    user_id: keith.id,
    company_id: keith_co.id,
    name: keith.name,
    organization: keith.organization,
    status: 0,
    terms_accepted: true
  })
end
