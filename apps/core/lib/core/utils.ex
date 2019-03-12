defmodule Core.Utils do

  @doc """
  Returns the current day in PST.
  """
  @spec today() :: Date.t
  def today do
    DateTime.utc_now()
    |> Timex.to_datetime("PST")
    |> DateTime.to_date()
  end

  @doc """
  Returns the current time in PST.
  """
  @spec now(integer) :: Time.t
  def now(offset_min \\ 0) do
    DateTime.utc_now()
    |> Timex.to_datetime("PST")
    |> DateTime.to_time()
    |> Time.add(offset_min * 60, :second)
    |> Time.truncate(:second)
  end

  @doc """
  Returns the minutes between the current time in PST and specified time.
  """
  @spec time_diff_in_min(Time.t) :: integer
  def time_diff_in_min(time) do
    DateTime.utc_now()
    |> Timex.to_datetime("PST")
    |> DateTime.to_time()
    |> Time.diff(time)
    |> Kernel./(60)
    |> round()
  end
end
