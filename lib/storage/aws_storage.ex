defmodule StorageAwsImpl do
  @behaviour StorageBehaviour

  @impl StorageBehaviour
  def download_file_stream(metadata, object) do
    bucket = metadata

    ExAws.S3.download_file(bucket, object, :memory)
    |> ExAws.stream!()
    |> Enum.map(& &1)
  end

  @impl StorageBehaviour
  def download_file_request(metadata, object, target) do
    bucket = metadata

    ExAws.S3.download_file(bucket, object, target)
    |> ExAws.request()
  end

  @impl StorageBehaviour
  def put_file(metadata, object, target) do
    bucket = metadata
    contents = File.read!(object)

    ExAws.S3.put_object(bucket, "uploads/#{target}", contents)
    |> ExAws.request!()
  end
end
