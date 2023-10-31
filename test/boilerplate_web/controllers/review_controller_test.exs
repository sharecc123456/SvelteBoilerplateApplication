defmodule BoilerplateWeb.ReviewControllerTest do
  use BoilerPlateWeb.ConnCase
  import BoilerPlate.Factory
  alias BoilerPlateWeb.ReviewController

  ###
  ### Helpers
  ###
  # this will only work for 0 or 1 reviews
  def verify_reviews(conn, count, params \\ %{}) do
    page = params["page"] || 1
    has_next = params["has_next"] || false
    total_pages = if count == 0, do: 0, else: params["total_pages"] || 1
    review = json_response(conn, 200)
    assert Enum.count(review["data"]) == count
    assert review["page"] == page
    assert review["has_next"] == has_next
    assert review["total_pages"] == total_pages
  end

  ###
  ### Actual Tests
  ###

  describe "Review API" do
    @tag :requestor
    test "can get all reviews", %{conn: conn, requestor_company: company} do
      # check for empty reviews
      params = %{
        "page" => 1,
        "search" => "",
        "sort" => "submitted",
        "sort_direction" => "desc"
      }

      conn = get(conn, "/n/api/v1/reviews-paginated", params)
      verify_reviews(conn, 0)
      # create a reivew
      insert_form_submission(conn, company)

      conn = get(conn, "/n/api/v1/reviews-paginated", params)
      verify_reviews(conn, 1)
    end

    @tag :requestor
    test "can search review", %{conn: conn, requestor_company: company} do
      insert_form_submission(conn, company)

      params = %{
        "page" => 1,
        "search" => "Form",
        "sort" => "submitted",
        "sort_direction" => "desc"
      }

      conn = get(conn, "/n/api/v1/reviews-paginated", params)
      verify_reviews(conn, 1)
    end

    @tag :requestor
    test "can sort reviews", %{conn: conn, requestor_company: company} do
      insert_form_submission(conn, company)
      insert_form_submission(conn, company)
      insert_form_submission(conn, company)

      params = %{
        "page" => 1,
        "search" => "Form",
        "sort" => "submitted",
        "sort_direction" => "desc"
      }

      conn = get(conn, "/n/api/v1/reviews-paginated", params |> Map.put("sort", "checklist_name"))
      verify_reviews(conn, 3)
      conn = get(conn, "/n/api/v1/reviews-paginated", params |> Map.put("sort", "recipient_name"))
      verify_reviews(conn, 3)

      conn =
        get(
          conn,
          "/n/api/v1/reviews-paginated",
          params |> Map.put("sort", "recipient_organization")
        )

      verify_reviews(conn, 3)
      conn = get(conn, "/n/api/v1/reviews-paginated", params |> Map.put("sort", "status"))
      verify_reviews(conn, 3)
      conn = get(conn, "/n/api/v1/reviews-paginated", params |> Map.put("sort", ""))
      verify_reviews(conn, 3)
    end

    ## unit tests
    test "can get file request type" do
      # post "/review/accept", ApiController, :requestor_review_accept
      attr = [0]
      type = ReviewController.get_document_request_type(attr)
      assert type == "file"
      attr = [1]
      type = ReviewController.get_document_request_type(attr)
      assert type == "task"
      attr = [2]
      type = ReviewController.get_document_request_type(attr)
      assert type == "data"
    end

    @tag :requestor
    test "can make request struct", %{requestor_company: company} do
      pkg = insert(:packages, %{company_id: company.id})
      req = insert(:document_request, %{packageid: pkg.id})
      dr = ReviewController.make_document_request(req)
      assert dr.id == req.id
      assert dr.type == "file"
      assert dr.new == false
    end

    @tag :requestor
    test "can make document struct", %{requestor_company: company} do
      upl = build(:upload, iac: true)
      rd = insert(:raw_document, %{company_id: company.id, file_name: upl})
      doc = ReviewController.make_doc_from_id(rd.id)
      assert doc.id == rd.id
      assert doc.file_name == rd.file_name
      assert doc.description == rd.description
    end
  end
end
