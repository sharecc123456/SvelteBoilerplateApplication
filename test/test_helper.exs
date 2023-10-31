ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(BoilerPlate.Repo, :manual)

# Clear the files in uploads folder if exists
if File.exists?("uploads") do
  if File.dir?("uploads") do
    File.rm_rf!("uploads")
    File.mkdir!("uploads")
  else
    raise ArgumentError, message: "uploads must be a folder if it exists"
  end
end
