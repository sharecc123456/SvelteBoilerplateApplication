defmodule BoilerPlate.DataManipulationUtils do
  @moduledoc """
    This is the Utility for date manipulation.
  """
  @moduledoc since: "1.0.0"

  @doc """
    Calculates delay between current time and next run time
    defaults time to midnight 0 0 0.

    returns: time diff in milliseconds
  """
  def calculate_next_cycle_delay(now, hour \\ 0, mins \\ 0, sec \\ 0) do
    now
    |> Timex.set(hour: hour, minute: mins, second: sec)
    |> maybe_shift_a_day(now)
    |> Timex.diff(now, :milliseconds)
  end

  def calculate_millisec_till_day(days_till) do
    days_till * 24 * 60 * 60 * 1000
  end

  @doc """
    shift the day by 1 if the current time is after set time

    returns: Timex
  """
  def maybe_shift_a_day(next_run, now) do
    case Timex.before?(now, next_run) do
      true ->
        next_run

      false ->
        Timex.shift(next_run, days: 1)
    end
  end
end
