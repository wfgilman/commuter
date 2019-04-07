defmodule Core.Schedule do
  import Ecto.Query

  defstruct [
    :trip_id,
    :etd,
    :eta,
    :duration_min,
    :stops,
    :prior_stops,
    :final_dest_code,
    :headsign,
    :headsign_code,
    :route_hex_color,
    :service_code,
    :etd_day_offset
  ]

  @type t :: %__MODULE__{
          trip_id: integer,
          etd: Time.t(),
          eta: Time.t(),
          duration_min: integer,
          stops: integer,
          prior_stops: integer,
          final_dest_code: String.t(),
          headsign: String.t(),
          headsign_code: String.t(),
          route_hex_color: String.t(),
          service_code: String.t(),
          etd_day_offset: integer
        }

  @doc """
  Gets schedule of all trips between two stations.
  """
  @spec get(String.t(), String.t()) :: [Core.Schedule.t()]
  def get(orig_station, dest_station) do
    from(s in subquery(schedule()),
      join: st in assoc(s, :station),
      join: t in assoc(s, :trip),
      join: svc in assoc(t, :service),
      join: r in assoc(t, :route),
      join: tls in assoc(t, :trip_last_station),
      join: fst in assoc(tls, :station),
      join: os in subquery(trips_through_station(orig_station)),
      on: s.trip_id == os.trip_id,
      join: ds in subquery(trips_through_station(dest_station)),
      on: s.trip_id == ds.trip_id,
      left_join: hs in Db.Model.Station,
      on: s.headsign == hs.name,
      where: st.code in [^orig_station, ^dest_station],
      where: os.sequence < ds.sequence,
      select: %{
        trip_id: s.trip_id,
        etd: over(min(s.departure_time), :trip),
        eta: over(max(s.arrival_time), :trip),
        first_stop_seq: over(min(s.sequence), :trip),
        last_stop_seq: over(max(s.sequence), :trip),
        final_dest_station_code: fst.code,
        headsign: s.headsign,
        headsign_code: hs.code,
        route_hex_color: r.color_hex_code,
        service_code: svc.code,
        etd_day_offset: s.departure_day_offset
      },
      windows: [trip: [partition_by: s.trip_id, order_by: s.sequence]],
      order_by: [s.departure_day_offset, s.departure_time]
    )
    |> Db.Repo.all()
    |> Stream.reject(&(&1.first_stop_seq == &1.last_stop_seq))
    |> Stream.map(fn depart ->
      %{
        trip_id: depart.trip_id,
        etd: depart.etd,
        eta: depart.eta,
        duration_min: round(Time.diff(depart.eta, depart.etd) / 60),
        stops: depart.last_stop_seq - depart.first_stop_seq,
        prior_stops: depart.first_stop_seq - 1,
        final_dest_code: depart.final_dest_station_code,
        headsign: depart.headsign,
        headsign_code: depart.headsign_code,
        route_hex_color: depart.route_hex_color,
        service_code: depart.service_code,
        etd_day_offset: depart.etd_day_offset
      }
    end)
    |> Enum.map(&struct(__MODULE__, &1))
  end

  defp schedule do
    from(s in Db.Model.Schedule,
      select: %{
        s
        | departure_day_offset:
            fragment("CASE WHEN ? < '04:00:00'::time THEN 1 ELSE 0 END", s.departure_time),
          arrival_day_offset:
            fragment("CASE WHEN ? < '04:00:00'::time THEN 1 ELSE 0 END", s.arrival_time)
      }
    )
  end

  defp trips_through_station(station) do
    from(s in Db.Model.Schedule,
      join: st in assoc(s, :station),
      where: st.code == ^station,
      select: %{
        trip_id: s.trip_id,
        sequence: s.sequence
      }
    )
  end
end
