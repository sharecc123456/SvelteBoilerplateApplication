alias BoilerPlate.StorageProvider
alias BoilerPlate.Repo

defmodule BoxOauthStorage do
  @behaviour StorageBehaviour

  @impl StorageBehaviour
  def download_file_stream(_bucket, object) do
    File.read!("#{object}")
  end

  @impl StorageBehaviour
  def download_file_request(_bucket, object, target) do
    File.cp!(object, target)
  end

  @impl StorageBehaviour
  def put_file(_bucket, object, target) do
    File.cp!(object, target)

    :ok
  end

  defp store_refresh_token(sp, rf) do
    Repo.update!(
      StorageProvider.changeset(sp, %{
        meta_data: %{refresh_token: rf}
      })
    )
  end

  defp get_client(sp) do
    rf = sp.meta_data["refresh_token"]

    case BoilerPlate.OAuthStrategies.BoxOauthStrategy.get_access_token(rf) do
      {:ok, client} ->
        {:ok, client}

      {:new_refresh_token, rf, client} ->
        store_refresh_token(sp, rf)
        {:ok, client}

      {:error, err} ->
        {:error, err}
    end
  end

  @storage_mod Application.compile_env(:boilerplate, :storage_backend, StorageAwsImpl)
  def new_password(length) do
    alphabet = Enum.to_list(?a..?z) ++ Enum.to_list(?0..?9)
    for _ <- 1..length, into: "", do: <<Enum.random(alphabet)>>
  end

  @testing_mode false
  def put_with_storage_provider(sp, filename, vars \\ %{}, rename_to) do
    {:ok, client} = get_client(sp)

    client = APIs.Box.new(client.token.access_token)
    bucket = Application.get_env(:boilerplate, :s3_bucket)
    file_body = @storage_mod.download_file_stream(bucket, "uploads/#{filename}")

    if not @testing_mode do
      folder_id =
        StorageProvider.walk_path(
          sp,
          client,
          sp.path_template,
          vars,
          create: true
        )

      APIs.Box.create_file(client, folder_id, rename_to, file_body)

      :ok
    else
      folder_id =
        StorageProvider.walk_path(
          sp,
          client,
          "/Boilerplate Uploads/$FULLNAME",
          %{full_name: "John Doe"},
          create: true
        )

      IO.inspect(%{msg: "put_with_storage_provider/box", folder_id: folder_id})

      file = APIs.Box.create_file(client, folder_id, filename, file_body)

      IO.inspect(file, label: "file")

      :ok
    end
  end
end
