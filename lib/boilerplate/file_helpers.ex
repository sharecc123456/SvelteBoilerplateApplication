defmodule BoilerPlate.FileHelpers do

  @allowed_iac_image_types ~w(.png .gif .jpg .jpeg .hevc .heic .heif .avif .avifs)

  def get_blpt_mergeable_file_types(), do: @allowed_iac_image_types

  def is_file_mergable_type?(file) do
    get_blpt_mergeable_file_types()
    |> Enum.member?(String.downcase(Path.extname(file.filename)))
  end
end
