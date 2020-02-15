defmodule Core.Departure do
  import Shared.Utils

  defstruct [
    :std,
    :etd,
    :etd_min,
    :eta,
    :delay_min,
    :duration_min,
    :stops,
    :prior_stops,
    :headsign,
    :headsign_code,
    :final_dest_code,
    :length,
    :trip_id,
    :route_hex_color,
    :notify,
    :real_time
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
          headsign: String.t(),
          headsign_code: String.t(),
          final_dest_code: String.t(),
          length: integer,
          trip_id: integer,
          route_hex_color: String.t(),
          notify: boolean,
          real_time: boolean
        }

  @doc """
  Get scheduled departues adjusted for real-time estimates.
  """
  @spec get(String.t(), String.t(), integer, boolean, String.t() | nil) ::
          {[Core.Departure.t()], NaiveDateTime.t()}
  def get(orig_station, dest_station, count, real_time \\ true, device_id \\ nil) do
    departs =
      if real_time == true do
        task = Task.async(fn -> Bart.Etd.get(orig_station) end)
        scheds = Core.Schedule.get(orig_station, dest_station)
        trip_ids = Core.Notification.get_trip_ids(device_id)

        rtds =
          case Task.yield(task, 3_000) || Task.shutdown(task) do
            {:ok, reply} ->
              reply

            nil ->
              nil
          end

        combine(scheds, trip_ids, count, rtds)
      else
        scheds = Core.Schedule.get(orig_station, dest_station)
        trip_ids = Core.Notification.get_trip_ids(device_id)

        combine(scheds, trip_ids, count)
      end

    {departs, current_datetime()}
  end

  defp combine(scheds, trip_ids, count, rtds \\ nil) do
    scheds
    |> filter_current_service()
    |> add_notifications(trip_ids)
    |> add_real_time_departures(rtds)
    |> sort_filter_and_map(count)
  end

  defp filter_current_service(scheds) do
    svcs = Enum.map(Core.Service.current_services(), &(&1.code))

    Stream.filter(scheds, fn sched ->
      sched.service_code in svcs
    end)
  end

  defp add_notifications(scheds, trip_ids) do
    Stream.map(scheds, fn sched ->
      case Enum.find(trip_ids, &(&1 == sched.trip_id)) do
        nil ->
          Map.put(sched, :notify, false)

        _ ->
          Map.put(sched, :notify, true)
      end
    end)
  end

  defp add_real_time_departures(scheds, rtd) do
    Enum.map(scheds, fn sched ->
      case find_matching_estimate(sched, flatten(rtd)) do
        nil ->
          sched
          |> Map.put(:std, sched.etd)
          |> Map.put(:delay_min, 0)
          |> Map.put(
            :etd_min,
            if(sched.etd_day_offset == 1,
              do: time_diff_in_min(sched.etd) + 24 * 60,
              else: time_diff_in_min(sched.etd)
            )
          )
          |> Map.put(:real_time, false)

        est ->
          sched
          |> Map.put(:std, est.etd_sch)
          |> Map.put(:etd, Time.truncate(est.etd_rt, :second))
          |> Map.put(:etd_min, est.minutes)
          |> Map.put(:delay_min, round(est.delay / 60))
          |> Map.put(:eta, Time.truncate(Time.add(est.etd_rt, sched.duration_min * 60), :second))
          |> Map.put(:length, est.length)
          |> Map.put(:real_time, true)
      end
    end)
  end

  defp sort_filter_and_map(scheds, count) do
    scheds
    |> Enum.sort_by(&{&1.etd_day_offset, Time.to_erl(&1.etd)}, &<=/2)
    |> Enum.reject(fn sched ->
      Time.compare(sched.etd, now()) == :lt
    end)
    |> Enum.take(count)
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
end
