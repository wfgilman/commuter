defmodule Core.Departure do
  defstruct [
    :std,
    :etd,
    :etd_min,
    :eta,
    :delay_min,
    :duration_min,
    :stops,
    :prior_stops,
    :orig_code,
    :orig_name,
    :dest_code,
    :dest_name,
    :headsign,
    :length
  ]

  @type t :: %__MODULE__{
          std: Time.t(),
          etd: Time.t(),
          etd_min: integer,
          eta: Time.t(),
          delay_min: integer,
          duration_min: integer,
          stops: integer,
          prior_stops: integer,
          orig_code: String.t(),
          orig_name: String.t(),
          dest_code: String.t(),
          dest_name: String.t(),
          headsign: String.t(),
          length: integer
        }

  @doc """
  Get scheduled departues adjusted for real-time estimates.
  """
  @spec get(String.t(), String.t(), String.t(), integer) :: [Core.Estimate.t()]
  def get(orig_station, dest_station, direction, count \\ 10) do
    rtd = Bart.Etd.get(orig_station, direction)
    sch = Core.Schedule.get(orig_station, dest_station, direction, count)
    combine(rtd, sch)
  end

  defp combine(rtd, sch) do
    estimates = estimates_from_rtd(rtd)

    sch
    |> Enum.map(fn sched ->
      case Enum.find(estimates, &fuzzy_match(sched.etd, &1.etd_sch)) do
        nil ->
          sched
          |> Map.put(:std, sched.etd)
          |> Map.put(:delay_min, 0)

        est ->
          sched
          |> Map.put(:std, est.etd_sch)
          |> Map.put(:etd, Time.truncate(est.etd_rt, :second))
          |> Map.put(:etd_min, est.minutes)
          |> Map.put(:delay_min, round(est.delay / 60))
          |> Map.put(:eta, Time.truncate(Time.add(est.etd_rt, sched.duration_min * 60), :second))
          |> Map.put(:length, est.length)
      end
    end)
    |> Enum.map(fn s ->
      struct(__MODULE__, Map.from_struct(s))
    end)
  end

  defp estimates_from_rtd(%Bart.Etd{time: time} = rtd) do
    t = nearest_minute(time)

    rtd
    |> Map.get(:station)
    |> Enum.map(&Map.get(&1, :etd))
    |> List.flatten()
    |> Enum.map(&Map.get(&1, :estimate))
    |> List.flatten()
    |> Enum.map(&Map.put(&1, :etd_rt, Time.add(t, &1.minutes * 60, :second)))
    |> Enum.map(
      &Map.put(&1, :etd_sch, nearest_minute(Time.add(t, &1.minutes * 60 - &1.delay, :second)))
    )
    |> Enum.sort_by(&Time.to_erl(&1.etd_sch), &<=/2)
  end

  defp nearest_minute(time) do
    {h, m, _} = Time.to_erl(time)
    {:ok, t} = Time.new(h, m, 0)
    t
  end

  defp fuzzy_match(sch_etd, rtd_etd) do
    diff = Time.diff(sch_etd, rtd_etd, :second)
    abs(diff) <= 60
  end
end
