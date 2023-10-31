defmodule APIs.Box do
  def new(access_token) do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, "https://api.box.com"},
      {Tesla.Middleware.BearerAuth, token: access_token},
      Tesla.Middleware.JSON
    ])
  end

  def create_folder(client, folder_name, parent_id \\ 0) do
    case Tesla.post(client, "/2.0/folders", %{
           name: folder_name,
           parent: %{
             id: parent_id
           }
         }) do
      {:ok, resp} ->
        case resp.status do
          200 ->
            resp.body

          201 ->
            resp.body

          _ ->
            {:error, resp}
        end

      e ->
        e
    end
  end

  def check_folder_exists(client, root_id, folder_name) do
    case Tesla.get(client, "/2.0/folders/#{root_id}/items") do
      {:ok, resp} ->
        case resp.status do
          200 ->
            Enum.find(resp.body["entries"], fn x ->
              x["name"] == folder_name
            end)

          _ ->
            {:error, resp}
        end
    end
  end

  def create_file(client, folder_id, file_name, body) do
    metadata =
      Poison.encode!(%{
        name: file_name,
        parent: %{
          id: folder_id
        }
      })

    mp =
      Tesla.Multipart.new()
      |> Tesla.Multipart.add_field("attributes", metadata)
      |> Tesla.Multipart.add_file_content(body, "file", name: "file")

    case Tesla.post(client, "https://upload.box.com/api/2.0/files/content", mp) do
      {:ok, resp} ->
        case resp.status do
          200 ->
            resp.body

          201 ->
            resp.body

          _ ->
            {:error, resp}
        end

      e ->
        e
    end
  end
end
