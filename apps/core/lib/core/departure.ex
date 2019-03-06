defmodule Core.Departure do
  import Ecto.Query

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

    {departs, now(:to_datetime)}
  end

  defp combine(scheds, trip_ids, count, rtds \\ nil) do
    scheds
    |> filter_current_service()
    |> add_notifications(trip_ids)
    |> add_real_time_departures(rtds)
    |> sort_filter_and_map(count)
  end

  defp filter_current_service(scheds) do
    Stream.filter(scheds, fn sched ->
      sched.service_code == current_service()
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
              do: get_etd_min(sched.etd) + 24 * 60,
              else: get_etd_min(sched.etd)
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

  @doc """
  Returns the code for the train service currently running.
  """
  @spec current_service() :: String.t
  def current_service do
    holiday =
      Db.Repo.one(
        from(se in Db.Model.ServiceException,
          join: s in assoc(se, :service),
          preload: [service: s],
          where: se.date == ^now(:to_date)
        )
      )

    day_of_week = Date.day_of_week(now(:to_date))
    current_time = now()
    {:ok, start_of_service} = Time.new(3, 0, 0)

    cond do
      is_nil(holiday) ->
        derive_service(day_of_week, current_time, start_of_service)

      not is_nil(holiday) and Time.compare(current_time, start_of_service) == :lt ->
        derive_service(day_of_week, current_time, start_of_service)

      true ->
        holiday.service.code
    end
  end

  defp derive_service(day_of_week, current_time, start_of_service) do
    cond do
      day_of_week == 6 and Time.compare(current_time, start_of_service) == :lt ->
        "WKDY"

      day_of_week == 6 and Time.compare(current_time, start_of_service) == :gt ->
        "SAT"

      day_of_week == 7 and Time.compare(current_time, start_of_service) == :lt ->
        "SAT"

      day_of_week == 7 and Time.compare(current_time, start_of_service) == :gt ->
        "SUN"

      Time.compare(current_time, start_of_service) == :lt ->
        "SUN"

      true ->
        "WKDY"
    end
  end

  defp get_etd_min(etd_time) do
    now = Time.add(Time.utc_now(), -28_800, :second)
    round(Time.diff(etd_time, now) / 60)
  end

  defp now(to? \\ :to_time) do
    utc_pst_offset_seconds = -28_800
    naive_dt = NaiveDateTime.add(NaiveDateTime.utc_now(), utc_pst_offset_seconds, :second)

    case to? do
      :to_date ->
        NaiveDateTime.to_date(naive_dt)

      :to_datetime ->
        NaiveDateTime.truncate(naive_dt, :second)

      _ ->
        naive_dt |> NaiveDateTime.to_time() |> Time.truncate(:second)
    end
  end
end
