defmodule Core.ETA do
  defstruct [:next_station, :next_station_eta_min, :eta, :eta_min]

  @type t :: %__MODULE__{
          next_station: Db.Model.Station.t(),
          next_station_eta_min: integer,
          eta: Time.t(),
          eta_min: integer
        }

  import Ecto.Query

  @doc """
  Get ETA to the nearest station based on a location.
  """
  @spec get_from_location(float, float, Core.Commute.t()) :: Core.ETA.t() | nil
  def get_from_location(lat, lon, %Core.Commute{} = commute) do
    stops =
      commute
      |> get_stations_locations()
      |> Enum.map(fn station ->
        dist = Geocalc.distance_between([lat, lon], station.coordinates)
        Map.put(station, :current_location_dist, dist)
      end)

    last_stop = Enum.find(stops, &(&1.code == commute.dest_station_code))

    case Enum.find(stops, &(&1.current_location_dist < &1.prior_station_dist)) do
      nil ->
        nil

      departing_stop ->
        next_stops =
          stops
          |> Enum.reject(&(&1.sequence > last_stop.sequence))
          |> Enum.reject(&(&1.sequence < departing_stop.sequence))
          |> Enum.drop(1)
          |> Enum.map(fn stop ->
            time_factor = min(1, stop.current_location_dist / stop.prior_station_dist)
            Map.update!(stop, :prior_station_min, &(&1 * time_factor))
          end)

        next_stop = Enum.at(next_stops, 0)

        remaining_trip_min =
          Enum.reduce(next_stops, 0, fn stop, total_min ->
            round(stop.prior_station_min) + total_min
          end)

        eta =
          Time.utc_now()
          |> Time.add(-(8 * 60 * 60), :second)
          |> Time.add(remaining_trip_min * 60, :second)
          |> Time.truncate(:second)

        struct(__MODULE__,
          next_station: struct(Db.Model.Station, next_stop),
          next_station_eta_min: round(next_stop.prior_station_min),
          eta: eta,
          eta_min: remaining_trip_min
        )
    end
  end

  def get_stations_locations(commute) do
    from(s in Db.Model.Schedule,
      join: st in assoc(s, :station),
      join: t in assoc(s, :trip),
      join: gct in subquery(get_complete_trip(commute)),
      on: gct.trip_id == s.trip_id,
      join: r in assoc(t, :route),
      order_by: s.sequence,
      select: %{
        id: st.id,
        name: st.name,
        code: st.code,
        sequence: s.sequence,
        depart_time: s.departure_time,
        coordinates: %{
          lat: st.lat,
          lon: st.lon
        }
      }
    )
    |> Db.Repo.all()
    |> put_distance_between_stations()
    |> put_trip_durations()
  end

  defp put_distance_between_stations(stations) do
    stations
    |> Enum.map_reduce(nil, fn station, prior_station_coordinates ->
      updated_prior_station_coordinates =
        if is_nil(prior_station_coordinates),
          do: station.coordinates,
          else: prior_station_coordinates

      updated_station =
        Map.put(station, :prior_station_coordinates, updated_prior_station_coordinates)

      {updated_station, station.coordinates}
    end)
    |> Tuple.to_list()
    |> Enum.at(0)
    |> Enum.map(fn station ->
      dist_to_prior_station =
        Geocalc.distance_between(station.coordinates, station.prior_station_coordinates)

      station
      |> Map.put(:prior_station_dist, dist_to_prior_station)
      |> Map.delete(:prior_station_coordinates)
    end)
  end

  defp put_trip_durations(stations) do
    stations
    |> Enum.map_reduce(nil, fn stop, prior_depart_time ->
      updated_prior_depart_time =
        if is_nil(prior_depart_time), do: stop.depart_time, else: prior_depart_time

      updated_stop = Map.put(stop, :prior_depart_time, updated_prior_depart_time)
      {updated_stop, stop.depart_time}
    end)
    |> Tuple.to_list()
    |> Enum.at(0)
    |> Enum.map(fn stop ->
      min = Time.diff(stop.depart_time, stop.prior_depart_time, :second) / 60
      Map.put(stop, :prior_station_min, round(min))
    end)
  end

  defp get_complete_trip(%{route_code: code, direction: direction}) do
    from(s in Db.Model.Schedule,
      join: t in assoc(s, :trip),
      join: r in assoc(t, :route),
      where: r.code == ^code,
      where: t.direction == ^direction,
      group_by: s.trip_id,
      order_by: [desc: count(s.station_id)],
      limit: 1,
      select: %{
        trip_id: s.trip_id
      }
    )
  end
end
