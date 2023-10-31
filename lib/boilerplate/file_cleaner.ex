alias BoilerPlate.FileCleanerUtils

defmodule BoilerPlate.FileCleaner do
  use GenServer
  require Logger
  # running after one day, time in ms
  # @interval 86400000
  # @interval 180000
  def start_link(_arg) do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(state) do
    # Schedule work to be performed at some point
    run_cleaner()
    {:ok, state}
  end

  def handle_info(:auto_delete, state) do
    Logger.info("Starting File Cleaning")
    FileCleanerUtils.auto_deletion_for_companies()

    ts = get_current_timestamp()
    log_text = "File Cleaner Ran Successfully at TimeStamp: " <> ts <> "\n"
    File.write("file_cleaner.log", log_text)

    run_cleaner()

    Logger.info("Completed File Cleanning")
    {:noreply, state}
  end

  defp run_cleaner() do
    is_testing = FunWithFlags.enabled?(:retention_testing)

    run_after =
      if is_testing do
        180_000
      else
        86_400_000
      end

    # Process.send_after(self(), :auto_delete, run_after)
    BoilerPlateAssist.SendAfter.send_after(
      "File Cleaner",
      self(),
      :auto_delete,
      run_after
    )
  end

  def get_current_timestamp() do
    current_timestamp = DateTime.utc_now()
    Calendar.strftime(current_timestamp, "%Y/%m/%d, %H:%M:%S")
  end
end
