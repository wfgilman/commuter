defmodule Core.Departure do
  import Ecto.Query

  defstruct [
    :etd,
    :etd_min,
    :delay_min,
    :eta,
    :duration_min,
    :stops,
    :prior_stops,
    :dest_code,
    :dest_name,
    :headsign
  ]

  def get(start_station, end_station, direction) do
    from(s in Db.Model.Schedule,
      join: st in assoc(s, :station),
      join: tts in subquery(trips_through_station(start_station, direction)),
      on: s.trip_id == tts.trip_id,
      where: st.code in [^start_station, ^end_station],
      select: %{
        etd: over(min(s.departure_time), :trip),
        eta: over(max(s.arrival_time), :trip),
        first_stop_seq: over(min(s.sequence), :trip),
        last_stop_seq: over(max(s.sequence), :trip),
        start_station_code: over(min(st.code), :trip),
        start_station_name: over(min(st.name), :trip),
        end_station_code: over(max(st.code), :trip),
        end_station_name: over(max(st.name), :trip),
        headsign: s.headsign
      },
      windows: [trip: [partition_by: s.trip_id, order_by: s.sequence]]
    )
    |> Db.Repo.all()
    |> Stream.reject(&(&1.first_stop_seq == &1.last_stop_seq))
    |> Stream.map(fn depart ->
      %{
        etd: depart.etd,
        etd_min: round(Time.diff(depart.etd, current_time()) / 60),
        eta: depart.eta,
        duration_min: round(Time.diff(depart.eta, depart.etd) / 60),
        stops: depart.last_stop_seq - depart.first_stop_seq,
        prior_stops: depart.first_stop_seq - 1,
        dest_code: depart.end_station_code,
        dest_name: depart.end_station_name,
        headsign: depart.headsign
      }
    end)
    |> Enum.map(&struct(__MODULE__, &1))
  end

  defp trips_through_station(station, direction) do
    from(s in Db.Model.Schedule,
      join: st in assoc(s, :station),
      join: t in assoc(s, :trip),
      join: svc in assoc(t, :service),
      where: st.code == ^station and t.direction == ^direction and svc.code == ^current_service(),
      where: s.departure_time > ^current_time(-10),
      select: %{trip_id: s.trip_id}
    )
  end

  defp current_service do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.add(-28_800, :second)
    |> NaiveDateTime.to_date()
    |> Date.day_of_week()
    |> case do
      6 -> "SAT"
      7 -> "SUN"
      _ -> "WKDY"
    end
  end

  defp current_time(offset_min \\ 0) do
    Time.utc_now()
    |> Time.add(-28_800 + offset_min * 60, :second)
  end
end
