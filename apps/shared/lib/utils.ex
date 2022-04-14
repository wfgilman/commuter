defmodule Shared.Utils do

  @time_zone "America/Los_Angeles"

  @doc """
  Returns the current day in PST.
  """
  @spec today() :: Date.t()
  def today do
    DateTime.utc_now()
    |> Timex.to_datetime(@time_zone)
    |> DateTime.to_date()
  end

  @doc """
  Returns the current time in PST. Optionally accepts and offset in minutes.
  """
  @spec now(integer) :: Time.t()
  def now(offset_min \\ 0) do
    DateTime.utc_now()
    |> Timex.to_datetime(@time_zone)
    |> DateTime.to_time()
    |> Time.add(offset_min * 60, :second)
    |> Time.truncate(:second)
  end

  @doc """
  Returns the current datetime in PST.
  """
  @spec current_datetime() :: NaiveDateTime.t()
  def current_datetime do
    DateTime.utc_now()
    |> Timex.to_datetime(@time_zone)
    |> DateTime.to_naive()
    |> NaiveDateTime.truncate(:second)
  end

  @doc """
  Returns the minutes between the current time in PST and specified time. Returns
  positive value for future time, negative value for past time.
  """
  @spec time_diff_in_min(Time.t()) :: integer
  def time_diff_in_min(time) do
    DateTime.utc_now()
    |> Timex.to_datetime(@time_zone)
    |> DateTime.to_time()
    |> Time.diff(time)
    |> Kernel./(60)
    |> round()
    |> Kernel.*(-1)
  end
end
