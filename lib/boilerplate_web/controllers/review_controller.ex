alias BoilerPlate.Repo
alias BoilerPlate.User
alias BoilerPlate.IACDocument
alias BoilerPlate.RawDocument
alias BoilerPlate.RawDocumentCustomized
alias BoilerPlate.Package
alias BoilerPlate.PackageAssignment
alias BoilerPlate.Document
alias BoilerPlate.PackageContents
alias BoilerPlate.Recipient
alias BoilerPlate.DocumentRequest
alias BoilerPlate.RequestCompletion
alias BoilerPlateWeb.FormController
alias BoilerPlateWeb.IACController
alias BoilerPlate.IACDocument
alias BoilerPlate.RecipientTag
alias BoilerPlate.Helpers
import Ecto.Query
import Bitwise
require Logger

defmodule AtomKeysDecoder do
  def decode(json_str) do
    Poison.decode!(json_str, keys: :atoms, decoders: [atom_keys_decoder()])
  end

  defp atom_keys_decoder() do
    fn
      {:__struct__, _, ["Elixir.Map", entries]} ->
        Enum.reduce(entries, %{}, fn {key, value}, acc ->
          new_key =
            case String.to_existing_atom(key) do
              nil -> key
              atom -> atom
            end

          Map.put(acc, new_key, value)
        end)

      value ->
        value
    end
  end
end

defmodule BoilerPlateWeb.ReviewController do
  use BoilerPlateWeb, :controller

  defp has_any_rspec_doc?(docids) do
    Repo.all(from r in BoilerPlate.RawDocument, where: r.id in ^docids, select: r)
    |> Enum.any?(&((&1.flags &&& 2) == 2))
  end

  defp has_allowed_recipient_specific_file_uploads?(pkg) do
    query =
      from r in DocumentRequest,
        where: r.packageid == ^pkg.id and r.flags == 4 and r.status == 0,
        select: r

    ids_count = Repo.aggregate(query, :count, :id)

    if ids_count == 1 do
      true
    else
      false
    end
  end

  defp make_doc(doc) do
    iac_doc = IACDocument.get_for(:raw_document, doc)

    %{
      id: doc.id,
      name: doc.name,
      description: doc.description,
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
      updated_time: doc.updated_at |> Timex.format!("{0h12}:{0m}:{0s} {AM}")
    }
  end

  def make_doc_from_id(docid) do
    doc = Repo.get(RawDocument, docid)

    make_doc(doc)
  end

  def make_document_request(req) do
    %{
      id: req.id,
      name: req.title,
      description: req.description,
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
      flags: req.flags
    }
  end

  defp requests_in(pkg) do
    Repo.all(
      from r in DocumentRequest, where: r.packageid == ^pkg.id and r.status == 0, select: r
    )
    |> Enum.map(&make_document_request/1)
  end

  def get_document_request_type(attr) do
    cond do
      1 in attr ->
        "task"

      2 in attr ->
        "data"

      true ->
        "file"
    end
  end

  def find_in_review(review, str) do
    %{"checklist" => checklist, "recipient" => recipient} = review

    Helpers.findInRecipient?(recipient, str) || Helpers.findInChecklist?(checklist, str) ||
      Helpers.stringContains?(review.requestor_description, str) ||
      Helpers.stringContains?(review.recipient_description, str)
  end

  def requestor_reviews_contents(conn, %{"cid" => contents_id}) do
    company = get_current_requestor(conn, as: :company)
    content = Repo.get(PackageContents, contents_id)
    ass = Repo.get_by(PackageAssignment, %{company_id: company.id, contents_id: content.id})

    {:ok, {:ok, cache_data}} =
      BoilerPlate.DashboardCache.get_contents_review(
        :dashboard_cache,
        ass.recipient_id,
        content.id
      )

    if cache_data != nil do
      text(conn, cache_data)
    else
      documents =
        Repo.all(
          from d in Document,
            join: rd in RawDocument,
            on: rd.id == d.raw_document_id,
            where:
              d.company_id == ^company.id and d.status == 1 and d.assignment_id == ^ass.id and
                d.recipient_id == ^content.recipient_id and
                d.raw_document_id in ^content.documents,
            order_by: [desc: d.inserted_at],
            select: %{doc: d, rd: rd}
        )
        |> Enum.uniq_by(fn %{rd: r, doc: _} -> r.id end)

      requests =
        Repo.all(
          from r in RequestCompletion,
            where:
              r.company_id == ^company.id and (r.status == 1 or r.status == 5) and
                r.assignment_id == ^ass.id and
                r.recipientid == ^content.recipient_id and r.requestid in ^content.requests,
            join: dr in DocumentRequest,
            on: dr.id == r.requestid,
            order_by: r.inserted_at,
            select: %{
              id: r.id,
              type: :request,
              name: dr.title,
              request_type: "data",
              attributes: dr.attributes,
              description: dr.description,
              status: r.status,
              filename: r.file_name,
              return_reason: r.return_comments,
              inserted_at: r.inserted_at,
              request_id: dr.id,
              link: dr.link
            }
        )
        |> Enum.uniq_by(fn %{request_id: i} -> i end)

      recipient = Repo.get(Recipient, content.recipient_id)
      n = %{
        contents_id: content.id,
        recipient_id: content.recipient_id,
        checklist_id: content.package_id,
        assignment_id: ass.id,
        recipient_description: content.recipient_description,
        requestor_description: content.req_checklist_identifier,
        documents:
          Enum.map(documents, fn %{doc: doc, rd: rd} ->
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

                if rd.type == 0 and IACDocument.setup_for?(:raw_document_customized, rdc) do
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

            iac_assigned_form_id =
              if RawDocument.is_rspec?(rd) do
                iac_doc =Repo.get(IACDocument, iac_doc_id)
                case IACController.get_iaf_for_ifexists(recipient, company, iac_doc, content, nil) do
                  %{id: id} -> id
                  _ -> nil
                end
              else
                nil
              end

            %{
              id: doc.id,
              is_rspec: RawDocument.is_rspec?(rd),
              is_info: RawDocument.is_info?(doc),
              iac_doc_id: iac_doc_id,
              contents_id: content.id,
              recipient_id: content.recipient_id,
              assignment_id: ass.id,
              allow_edits: rd.editable_during_review,
              type: :document,
              name: rd.name,
              description: rd.description,
              status: doc.status,
              filename: doc.filename,
              submitted:
                doc.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D} {0h12}:{0m}:{0s} {AM}"),
              base_document_id: doc.raw_document_id,
              iac_assigned_form_id: iac_assigned_form_id
            }
          end),
        requests:
          Enum.map(requests, fn req ->
            %{
              id: req.id,
              type: :request,
              name: req.name,
              request_type: get_document_request_type(req.attributes),
              description: req.description,
              status: req.status,
              filename: req.filename,
              return_reason: req.return_reason,
              submitted:
                req.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D} {0h12}:{0m}:{0s} {AM}"),
              request_id: req.request_id,
              link: req.link
            }
          end),
        forms: FormController.get_forms_for_contents(content.id, true)
      }

      fully_submitted =
        length(n.documents) == length(content.documents) and
          length(n.requests) == length(content.requests) and
          length(n.forms) == length(content.forms)

      fully_reviewed =
        (n.documents ++ n.requests ++ n.forms)
        |> Enum.map(& &1.status)
        |> tap(&IO.inspect(&1))
        |> Enum.all?(&(&1 == 2 or &1 == 3))

      first_submit =
        Enum.map(n.documents ++ n.requests ++ n.forms, & &1.submitted)
        |> Enum.sort()
        |> List.first()

      n = Map.put(n, :fully_submitted, fully_submitted)
      n = Map.put(n, :fully_reviewed, fully_reviewed)

      IO.inspect(%{
        fully_submitted: fully_submitted,
        fully_reviewed: fully_reviewed,
        status: ass.status,
        id: ass.id
      })

      n = Map.put(n, :submitted, first_submit)

      BoilerPlate.DashboardCache.set_contents_review(
        :dashboard_cache,
        ass.recipient_id,
        content.id,
        n
      )

      json(conn, n)
    end
  end

  def requestor_reviews(conn, params) do
    search = params["search"] || ""
    sort = String.to_atom(params["sort"] || "name")
    sort_direction = String.to_atom(params["sort_direction"] || "asc")
    {page, _} = Integer.parse(Helpers.get_param(params, "page", "1"))
    {per_page, _} = Integer.parse(Helpers.get_param(params, "per_page", "10"))

    company = get_current_requestor(conn, as: :company)

    assignments =
      Repo.all(
        from pa in PackageAssignment,
          where: pa.company_id == ^company.id and pa.status == 0,
          join: ca in PackageContents,
          on: ca.id == pa.contents_id,
          select: {pa, ca}
      )

    data =
      for {ass, content} <- assignments do
        {:ok, {:ok, cache_data}} =
          BoilerPlate.DashboardCache.get_contents_review(
            :dashboard_cache,
            ass.recipient_id,
            content.id
          )

        if cache_data != nil do
          AtomKeysDecoder.decode(cache_data)
        else
          documents =
            Repo.all(
              from d in Document,
                join: rd in RawDocument,
                on: rd.id == d.raw_document_id,
                where:
                  d.company_id == ^company.id and d.status == 1 and d.assignment_id == ^ass.id and
                    d.recipient_id == ^content.recipient_id and
                    d.raw_document_id in ^content.documents,
                order_by: [desc: d.inserted_at],
                select: %{doc: d, rd: rd}
            )
            |> Enum.uniq_by(fn %{rd: r, doc: _} -> r.id end)

          requests =
            Repo.all(
              from r in RequestCompletion,
                where:
                  r.company_id == ^company.id and (r.status == 1 or r.status == 5) and
                    r.assignment_id == ^ass.id and
                    r.recipientid == ^content.recipient_id and r.requestid in ^content.requests,
                join: dr in DocumentRequest,
                on: dr.id == r.requestid,
                order_by: r.inserted_at,
                select: %{
                  id: r.id,
                  type: :request,
                  name: dr.title,
                  request_type: "data",
                  attributes: dr.attributes,
                  description: dr.description,
                  status: r.status,
                  filename: r.file_name,
                  return_reason: r.return_comments,
                  inserted_at: r.inserted_at,
                  request_id: dr.id,
                  link: dr.link
                }
            )
            |> Enum.uniq_by(fn %{request_id: i} -> i end)

          n = %{
            contents_id: content.id,
            recipient_id: content.recipient_id,
            checklist_id: content.package_id,
            assignment_id: ass.id,
            recipient_description: content.recipient_description,
            requestor_description: content.req_checklist_identifier,
            documents:
              Enum.map(documents, fn %{doc: doc, rd: rd} ->
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

                    if rd.type == 0 and IACDocument.setup_for?(:raw_document_customized, rdc) do
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

                %{
                  id: doc.id,
                  is_rspec: RawDocument.is_rspec?(rd),
                  is_info: RawDocument.is_info?(doc),
                  iac_doc_id: iac_doc_id,
                  contents_id: content.id,
                  recipient_id: content.recipient_id,
                  assignment_id: ass.id,
                  allow_edits: rd.editable_during_review,
                  type: :document,
                  name: rd.name,
                  description: rd.description,
                  status: doc.status,
                  filename: doc.filename,
                  submitted:
                    doc.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D} {0h12}:{0m}:{0s} {AM}"),
                  base_document_id: doc.raw_document_id
                }
              end),
            requests:
              Enum.map(requests, fn req ->
                %{
                  id: req.id,
                  type: :request,
                  name: req.name,
                  request_type: get_document_request_type(req.attributes),
                  description: req.description,
                  status: req.status,
                  filename: req.filename,
                  return_reason: req.return_reason,
                  submitted:
                    req.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D} {0h12}:{0m}:{0s} {AM}"),
                  request_id: req.request_id,
                  link: req.link
                }
              end),
            forms: FormController.get_forms_for_contents(content.id, true)
          }

          fully_submitted =
            length(n.documents) == length(content.documents) and
              length(n.requests) == length(content.requests) and
              length(n.forms) == length(content.forms)

          fully_reviewed =
            (n.documents ++ n.requests ++ n.forms)
            |> Enum.map(& &1.status)
            |> tap(&IO.inspect(&1))
            |> Enum.all?(&(&1 == 2 or &1 == 3))

          first_submit =
            Enum.map(n.documents ++ n.requests ++ n.forms, & &1.submitted)
            |> Enum.sort()
            |> List.first()

          n = Map.put(n, :fully_submitted, fully_submitted)
          n = Map.put(n, :fully_reviewed, fully_reviewed)

          IO.inspect(%{
            fully_submitted: fully_submitted,
            fully_reviewed: fully_reviewed,
            status: ass.status,
            id: ass.id
          })

          n = Map.put(n, :submitted, first_submit)

          BoilerPlate.DashboardCache.set_contents_review(
            :dashboard_cache,
            ass.recipient_id,
            content.id,
            n
          )

          n
        end
      end

    # searching - recipient - name, email, company, checklists, documents, requests - name, desc
    final_data =
      data
      |> Enum.filter(&(&1.documents != [] || &1.requests != [] || &1.forms != []))
      |> Enum.map(fn r_item ->
        checklist = Repo.one(from p in Package, where: p.id == ^r_item.checklist_id, select: p)
        contents = Repo.get(PackageContents, r_item.contents_id)
        tags = Repo.all(from r in RecipientTag, where: r.id in ^contents.tags, select: r)

        cl = %{
          id: checklist.id,
          name: checklist.title,
          description: checklist.description,
          version_date: "N/A",
          last_used: "N/A",
          is_draft: checklist.status == 4,
          inserted_at: checklist.inserted_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
          inserted_time: checklist.inserted_at |> Timex.format!("{0h12}:{0m}:{0s} {AM}"),
          updated_at: checklist.updated_at |> Timex.format!("{YYYY}-{0M}-{0D}"),
          updated_time: checklist.updated_at |> Timex.format!("{0h12}:{0m}:{0s} {AM}"),
          file_requests: requests_in(checklist) |> Enum.filter(fn x -> x.flags != 4 end),
          documents: Enum.map(checklist.templates, fn x -> make_doc_from_id(x) end),
          has_rspec: has_any_rspec_doc?(checklist.templates),
          allowed_additional_files_uploads:
            has_allowed_recipient_specific_file_uploads?(checklist),
          forms: r_item.forms
        }

        recipient =
          Repo.one(
            from r in Recipient,
              where: r.id == ^r_item.recipient_id,
              join: u in User,
              on: u.id == r.user_id,
              select: %{
                id: r.id,
                name: r.name,
                email: u.email,
                inserted_at: r.inserted_at,
                updated_at: r.updated_at,
                company: r.organization,
                show_in_dashboard: r.show_in_dashboard
              }
          )

        tags = BoilerPlateWeb.DocumentTagView.render("recipient_tags.json", recipient_tags: tags)

        r_item |> Map.put_new("checklist", cl) |> Map.put_new("recipient", recipient) |> Map.put_new("tags", tags)
      end)

    filtered_data =
      if search != "" do
        final_data
        |> Enum.filter(fn r_item -> find_in_review(r_item, String.downcase(search)) end)
      else
        final_data
      end

    sorted_data =
      filtered_data
      |> Enum.sort_by(
        fn a ->
          %{"checklist" => checklist, "recipient" => recipient} = a

          case sort do
            :checklist_name ->
              String.downcase(checklist.name)

            :recipient_name ->
              String.downcase(recipient.name)

            :recipient_organization ->
              String.downcase(recipient.company)

            :submitted ->
              a.submitted

            :status ->
              a.fully_submitted

            _ ->
              a.submitted
          end
        end,
        sort_direction
      )

    total_pages = ceil(Enum.count(sorted_data) / per_page)

    paginated_data =
      sorted_data
      |> Enum.slice((page - 1) * per_page, per_page)

    json(conn, %{
      data: paginated_data,
      page: page,
      total_pages: total_pages,
      has_next: page < total_pages
    })
  end
end
