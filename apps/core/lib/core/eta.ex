defmodule Core.ETA do
  defstruct [:station, :eta, :eta_min, :location]

  @type t :: %__MODULE__{
          station: Db.Model.Station.t(),
          eta: Time.t(),
          eta_min: integer,
          location: map
        }

  import Ecto.Query

  @doc """
  Get ETA to the nearest station based on a location.
  """
  @spec get_from_location(float, float, Core.Commute.t()) :: Core.ETA.t() | nil
  def get_from_location(lat, lon, %Core.Commute{} = commute) do
    case get_nearest_station(lat, lon, commute) do
      nil ->
        nil

      orig ->
        dist_factor = orig.dist_to_location / orig.dist_to_prior_station
        durations = get_trip_durations(commute)

        orig_seq =
          durations
          |> Enum.find(&(&1.station_code == orig.code))
          |> Map.get(:sequence)

        dest_seq =
          durations
          |> Enum.find(&(&1.station_code == commute.dest_station_code))
          |> Map.get(:sequence)

        eta_min =
          durations
          |> Enum.filter(fn stop ->
            stop.sequence >= orig_seq and stop.sequence <= dest_seq
          end)
          |> Enum.reduce([], fn stop, acc ->
            factor = if Enum.empty?(acc), do: dist_factor, else: 1
            updated_stop = Map.update!(stop, :duration_min, &round(&1 * factor))
            [updated_stop | acc]
          end)
          |> Enum.reduce(0, fn stop, acc ->
            stop.duration_min + acc
          end)

        eta =
          Time.utc_now()
          |> Time.add(-(8 * 60 * 60), :second)
          |> Time.add(eta_min * 60, :second)
          |> Time.truncate(:second)

        struct(__MODULE__,
          station: struct(Db.Model.Station, orig),
          eta: eta,
          eta_min: eta_min,
          location: orig.location
        )
    end
  end

  defp get_nearest_station(lat, lon, commute) do
    commute
    |> get_stations_locations()
    |> Enum.map(fn station ->
      dist = Geocalc.distance_between([lat, lon], station.location)
      Map.put(station, :dist_to_location, dist)
    end)
    |> Enum.filter(fn station ->
      station.dist_to_location < station.dist_to_prior_station
    end)
    |> Enum.sort_by(& &1.dist_to_location, &>=/2)
    |> Enum.at(0)
  end

  defp get_stations_locations(commute) do
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
        location: %{
          lat: st.lat,
          lon: st.lon
        }
      }
    )
    |> Db.Repo.all()
    |> put_distance_between_stations()
  end

  defp put_distance_between_stations(stations) do
    stations
    |> Enum.map_reduce(nil, fn station, acc ->
      prior_location = if is_nil(acc), do: station.location, else: acc
      updated_station = Map.put(station, :prior_station_location, prior_location)
      {updated_station, station.location}
    end)
    |> Tuple.to_list()
    |> Enum.at(0)
    |> Enum.map(fn station ->
      dist_to_prior_station =
        Geocalc.distance_between(station.location, station.prior_station_location)

      station
      |> Map.put(:dist_to_prior_station, dist_to_prior_station)
      |> Map.delete(:prior_station_location)
    end)
  end

  defp get_trip_durations(commute) do
    from(s in Db.Model.Schedule,
      join: st in assoc(s, :station),
      join: gct in subquery(get_complete_trip(commute)),
      on: gct.trip_id == s.trip_id,
      order_by: s.sequence,
      select: %{
        station_code: st.code,
        sequence: s.sequence,
        depart_time: s.departure_time
      }
    )
    |> Db.Repo.all()
    |> Enum.map_reduce(nil, fn stop, acc ->
      prior_depart_time = if is_nil(acc), do: stop.depart_time, else: acc
      updated_stop = Map.put(stop, :prior_depart_time, prior_depart_time)
      {updated_stop, stop.depart_time}
    end)
    |> Tuple.to_list()
    |> Enum.at(0)
    |> Enum.map(fn stop ->
      min = Time.diff(stop.depart_time, stop.prior_depart_time, :second) / 60
      Map.put(stop, :duration_min, round(min))
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
