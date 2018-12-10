defmodule Core.Schedule do
  import Ecto.Query

  defstruct [
    :trip_id,
    :etd,
    :etd_min,
    :eta,
    :duration_min,
    :stops,
    :prior_stops,
    :dest_code,
    :dest_name,
    :orig_code,
    :orig_name,
    :final_dest_code,
    :headsign,
    :route_hex_color
  ]

  @type t :: %__MODULE__{
          trip_id: integer,
          etd: Time.t(),
          etd_min: integer,
          eta: Time.t(),
          duration_min: integer,
          stops: integer,
          prior_stops: integer,
          dest_code: String.t(),
          dest_name: String.t(),
          orig_code: String.t(),
          orig_name: String.t(),
          final_dest_code: String.t(),
          headsign: String.t(),
          route_hex_color: String.t()
        }

  @doc """
  Gets schedule of all trips between two stations.
  """
  @spec get(String.t(), String.t(), integer) :: [Core.Schedule.t()]
  def get(orig_station, dest_station, count) do
    from(s in Db.Model.Schedule,
      join: st in assoc(s, :station),
      join: os in subquery(trips_through_station(orig_station)),
      on: s.trip_id == os.trip_id,
      join: ds in subquery(trips_through_station(dest_station)),
      on: s.trip_id == ds.trip_id,
      where: st.code in [^orig_station, ^dest_station],
      where: os.sequence < ds.sequence,
      select: %{
        trip_id: s.trip_id,
        etd: over(min(s.departure_time), :trip),
        eta: over(max(s.arrival_time), :trip),
        first_stop_seq: over(min(s.sequence), :trip),
        last_stop_seq: over(max(s.sequence), :trip),
        orig_station_code: over(min(st.code), :trip),
        orig_station_name: over(min(st.name), :trip),
        dest_station_code: over(max(st.code), :trip),
        dest_station_name: over(max(st.name), :trip),
        final_dest_station_code: os.final_dest_code,
        headsign: s.headsign,
        route_hex_color: os.route_hex_color
      },
      windows: [trip: [partition_by: s.trip_id, order_by: s.sequence]],
      order_by: s.departure_time
    )
    |> Db.Repo.all()
    |> Stream.reject(&(&1.first_stop_seq == &1.last_stop_seq))
    |> Stream.map(fn depart ->
      %{
        trip_id: depart.trip_id,
        etd: depart.etd,
        etd_min: round(Time.diff(depart.etd, current_time()) / 60),
        eta: depart.eta,
        duration_min: round(Time.diff(depart.eta, depart.etd) / 60),
        stops: depart.last_stop_seq - depart.first_stop_seq,
        prior_stops: depart.first_stop_seq - 1,
        dest_code: depart.dest_station_code,
        dest_name: depart.dest_station_name,
        orig_code: depart.orig_station_code,
        orig_name: depart.orig_station_name,
        final_dest_code: depart.final_dest_station_code,
        headsign: depart.headsign,
        route_hex_color: depart.route_hex_color
      }
    end)
    |> Stream.take(count)
    |> Enum.map(&struct(__MODULE__, &1))
  end

  defp trips_through_station(station) do
    from(s in Db.Model.Schedule,
      join: st in assoc(s, :station),
      join: t in assoc(s, :trip),
      join: r in assoc(t, :route),
      join: svc in assoc(t, :service),
      join: tls in assoc(t, :trip_last_station),
      join: fst in assoc(tls, :station),
      where: st.code == ^station,
      where: svc.code == ^current_service(),
      where: s.departure_time > ^current_time(),
      select: %{
        trip_id: s.trip_id,
        sequence: s.sequence,
        final_dest_code: fst.code,
        route_hex_color: r.color_hex_code
      }
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
