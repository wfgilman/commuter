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
    :final_dest_code,
    :length,
    :trip_id,
    :route_hex_color,
    :notify
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
          final_dest_code: String.t(),
          length: integer,
          trip_id: integer,
          route_hex_color: String.t(),
          notify: boolean
        }

  @doc """
  Get scheduled departues adjusted for real-time estimates.
  """
  @spec get(String.t(), String.t(), integer, String.t() | nil) :: [Core.Estimate.t()]
  def get(orig_station, dest_station, count, device_id \\ nil) do
    task = Task.async(fn -> Bart.Etd.get(orig_station) end)
    sch = Core.Schedule.get(orig_station, dest_station, count)
    trip_ids = Core.Notification.get_trip_ids(device_id)

    rtd =
      case Task.yield(task, 3_000) || Task.shutdown(task) do
        {:ok, reply} ->
          reply

        nil ->
          nil
      end

    combine(rtd, sch, trip_ids)
  end

  defp combine(rtd, sch, trip_ids) do
    sch
    |> Enum.map(fn sched ->
      case find_matching_estimate(sched, flatten(rtd)) do
        nil ->
          sched
          |> Map.put(:std, sched.etd)
          |> Map.put(:delay_min, 0)
          |> Map.put(
            :etd_min,
            if(next_day(sched.etd), do: sched.etd_min + 1_440, else: sched.etd_min)
          )

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
    |> Enum.sort_by(&{next_day(&1.etd), Time.to_erl(&1.etd)}, &<=/2)
    |> Enum.map(fn sched ->
      case Enum.find(trip_ids, &(&1 == sched.trip_id)) do
        nil ->
          Map.put(sched, :notify, false)

        _ ->
          Map.put(sched, :notify, true)
      end
    end)
    |> Enum.map(fn sched ->
      struct(__MODULE__, Map.from_struct(sched))
    end)
  end

  # No response from BART API.
  defp flatten(nil), do: []

  defp flatten(%Bart.Etd{time: time} = rtd) do
    rtd.station
    |> Enum.map(&flatten(&1, nearest_minute(time)))
    |> List.flatten()
  end

  defp flatten(%Bart.Etd.Station{} = station, time) do
    Enum.map(station.etd, &flatten(&1, time))
  end

  defp flatten(%Bart.Etd.Station.Etd{abbreviation: dest_code} = etd, time) do
    Enum.map(etd.estimate, &flatten(&1, time, dest_code))
  end

  defp flatten(%Bart.Etd.Station.Etd.Estimate{} = est, time, dest_code) do
    est
    |> Map.put(:etd_rt, Time.add(time, est.minutes * 60, :second))
    |> Map.put(:etd_sch, nearest_minute(Time.add(time, est.minutes * 60 - est.delay, :second)))
    |> Map.put(:dest_code, dest_code)
  end

  defp nearest_minute(time) do
    {h, m, _} = Time.to_erl(time)
    {:ok, t} = Time.new(h, m, 0)
    t
  end

  defp find_matching_estimate(schedule, estimates) do
    Enum.find(estimates, fn estimate ->
      fuzzy_match_time(schedule.etd, estimate.etd_sch) and
        schedule.final_dest_code == estimate.dest_code
    end)
  end

  defp fuzzy_match_time(sch_etd, rtd_etd) do
    diff = Time.diff(sch_etd, rtd_etd, :second)
    abs(diff) <= 60
  end

  defp next_day(time) do
    {:ok, t} = Time.new(4, 0, 0)
    :lt == Time.compare(time, t)
  end
end
