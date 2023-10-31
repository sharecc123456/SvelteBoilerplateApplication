alias BoilerPlate.Repo
alias BoilerPlate.IACLabel
alias BoilerPlate.DocumentTag

default_nomad_label_set = [
  {"name_full", "Full Name"},
  {"name_first", "First Name"},
  {"name_middle", "Middle Name"},
  {"name_initials", "Initials"},
  {"name_middle_initial", "Middle Initials"},
  {"name_last", "Last Name"},
  {"name_suffix", "Suffix"},
  {"date_of_birth", "Date of Birth"},
  {"phone_number", "Phone Number"},
  {"ssn", "Social Security Number (SSN)"},
  {"address_full", "Full Address"},
  {"address_street_full", "Full Street"},
  {"address_street_number", "Street Number"},
  {"address_street_name", "Street Name"},
  {"address_street_unit", "Unit No"},
  {"address_city", "City"},
  {"address_state", "State"},
  {"address_country", "Country"},
  {"address_zip", "ZIP"},
  {"company_name", "Company Name"},
  {"company_entity_type", "Entity Type"},
  {"company_date_founded", "Date Founded"},
  {"company_ein", "Employer Identification Number (EIN)"},
  {"website_url", "Website Address"},
  {"company_point_of_contact_name", "Point of contact name"},
  {"company_point_of_contact_email", "Point of contact email"},
  {"company_point_of_contact_phone_number", "Point of contact phone"},
  {"company_point_of_contact_address_full", "Point of contact full address"},
  {"email_address", "Email"},
  {"contact_full_name", "Contact full Name"},
  {"organization", "Contact organization"},
  {"phone_number", "Contact Phonenumber"}
]

default_nomad_label_set
|> Enum.each(fn {label, question} ->
  Repo.insert!(%IACLabel{
    value: label,
    question: question,
    flags: 0,
    status: 0,
    company_id: nil,
    inserted_by: nil
  })
end)


# Document tag nomad seed
defaulf_nomad_document_tags = ["PII - Personal Info", "PHI - Health Info"]

defaulf_nomad_document_tags
|> Enum.each(fn tag ->
  Repo.insert!(%DocumentTag{
    name: tag,
    company_id: nil,
    color: nil,
    status: 0,
    sensitive_level: 0
  })
end)
