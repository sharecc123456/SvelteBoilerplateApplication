defmodule BoilerplateWeb.AdditionalFileUploadsTest do
  use BoilerPlateWeb.ConnCase
  import BoilerPlate.Factory

  describe "Additional file uploads" do
    @tag :recipient
    test "test single file upload test", %{conn: conn, recipient_company: company, recipient: nr} do
      pkg = insert(:packages, %{company_id: company.id})
      dr = insert(:document_request, %{packageid: 0})
      pc = insert(:package_contents, %{package_id: pkg.id, recipient_id: nr.id, requests: [dr.id]})

      upload = %Plug.Upload{path: "test/fixtures/bill-of-sale.pdf", filename: "bill-of-sale.pdf"}

      na = insert(:package_assignments, %{
        recipient_id: nr.id,
        contents_id: pc.id,
        package_id: pkg.id,
        company_id: company.id
      })

      conn = post(conn, "/n/api/v1/extra/requests/#{dr.id}", %{
        "file" => [upload],
        "recipientId" => nr.id,
        "assignmentId" => na.id,
        "requestName" => "request default name"
      })

      r = json_response(conn, 200)
      assert Map.has_key?(r, "id")
    end

    @tag :recipient
    test "test multiple file upload test", %{conn: conn, recipient_company: company, recipient: nr} do
      pkg = insert(:packages, %{company_id: company.id})
      dr = insert(:document_request, %{packageid: 0})
      pc = insert(:package_contents, %{package_id: pkg.id, recipient_id: nr.id, requests: [dr.id]})

      upload = %Plug.Upload{path: "test/fixtures/bill-of-sale.pdf", filename: "bill-of-sale.pdf"}

      na = insert(:package_assignments, %{
        recipient_id: nr.id,
        contents_id: pc.id,
        package_id: pkg.id,
        company_id: company.id
      })


      conn = post(conn, "/n/api/v1/extra/requests/#{dr.id}", %{
        "file" => [upload, upload, upload, upload],
        "recipientId" => nr.id,
        "assignmentId" => na.id,
        "requestName" => "request default name"
      })

      r = json_response(conn, 200)
      assert Map.has_key?(r, "id")
    end

    @tag :recipient
    test "test mergeable type single file upload test", %{conn: conn, recipient_company: company, recipient: nr} do
      pkg = insert(:packages, %{company_id: company.id})
      dr = insert(:document_request, %{packageid: 0})
      pc = insert(:package_contents, %{package_id: pkg.id, recipient_id: nr.id, requests: [dr.id]})

      upload = %Plug.Upload{path: "test/fixtures/duck.png", filename: "duck.png"}

      na = insert(:package_assignments, %{
        recipient_id: nr.id,
        contents_id: pc.id,
        package_id: pkg.id,
        company_id: company.id
      })


      conn = post(conn, "/n/api/v1/extra/requests/#{dr.id}", %{
        "file" => [upload],
        "recipientId" => nr.id,
        "assignmentId" => na.id,
        "requestName" => "request default name"
      })

      r = json_response(conn, 200)
      assert Map.has_key?(r, "id")
    end

    # the test tries to multiple images, but cannot find convert cmd from magick(installed in local machine)
    # @tag :recipient
    # test "test mergeable type multiple file upload test", %{conn: conn, recipient_company: company, recipient: nr} do
    #   pkg = insert(:packages, %{company_id: company.id})
    #   dr = insert(:document_request, %{packageid: 0})
    #   pc = insert(:package_contents, %{package_id: pkg.id, recipient_id: nr.id, requests: [dr.id]})

    #   # the script convert_to_pdf.sh had no file permission on test/fixtures/duck.png
    #   # dont know if this is a right way to set permission
    #   System.shell("chmod 750 test/fixtures/duck.png")

    #   upload = %Plug.Upload{path: "test/fixtures/duck.png", filename: "duck.png"}

    #   na = insert(:package_assignments, %{
    #     recipient_id: nr.id,
    #     contents_id: pc.id,
    #     package_id: pkg.id,
    #     company_id: company.id
    #   })


    #   conn = post(conn, "/n/api/v1/extra/requests/#{dr.id}", %{
    #     "file" => [upload, upload],
    #     "recipientId" => nr.id,
    #     "assignmentId" => na.id,
    #     "requestName" => "request default name"
    #   })

    #   r = json_response(conn, 200)
    #   assert Map.has_key?(r, "id")
    # end
  end
end
