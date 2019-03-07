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
  @spec calculate(float, float, Core.Commute.t()) :: Core.ETA.t() | nil
  def calculate(lat, lon, commute) do
    stations = get_stations(commute)
    coordinates = get_coordinates_between_location_and_closest_station(lat, lon, commute)
    next_stop = coordinates |> Enum.at(0) |> Map.get(:next_station)
    last_stop = Enum.find(stations, &(&1.code == commute.dest_station_code))
    current_location = List.first(coordinates)
    next_stop_location = List.last(coordinates)
    factor = 1 - current_location.intra_stop_sequence / next_stop_location.intra_stop_sequence

    stations =
      stations
      |> Enum.reject(&(&1.sequence < next_stop.sequence or &1.sequence > last_stop.sequence))
      |> Enum.reduce([], fn
        station, [] ->
          prior_station_min = round(station.prior_station_min * factor)
          station = %{station | prior_station_min: prior_station_min}
          [station]

        station, acc ->
          [station | acc]
      end)
      |> Enum.reverse()

    cond do
      stations == [] ->
        nil

      current_location.dist_from_location > 1_600 ->
        nil

      true ->
        assemble_results(stations, next_stop)
    end
  end

  def assemble_results(stations, next_stop) do
    updated_min = stations |> Enum.at(0) |> Map.get(:prior_station_min)
    next_stop = %{next_stop | prior_station_min: updated_min}

    remaining_trip_min =
      Enum.reduce(stations, 0, fn station, total_min ->
        station.prior_station_min + total_min
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

  def get_coordinates_between_location_and_closest_station(lat, lon, commute) do
    coordinates = get_shape_coordinates(commute)
    stations = get_stations(commute)

    coordinates
    |> Enum.map(fn coordinate ->
      station = get_closest_station(stations, coordinate)
      Map.put(coordinate, :next_station, station)
    end)
    |> Enum.map(fn coordinate ->
      dist_from_location = Geocalc.distance_between(%{lat: lat, lon: lon}, coordinate)
      Map.put(coordinate, :dist_from_location, dist_from_location)
    end)
    |> Enum.reduce([], fn
      coordinate, [] ->
        coordinate = Map.put(coordinate, :intra_stop_sequence, 1)
        [coordinate]

      coordinate, [prior_coordinate | _] = acc ->
        coordinate =
          if coordinate.next_station.code == prior_coordinate.next_station.code do
            Map.put(coordinate, :intra_stop_sequence, prior_coordinate.intra_stop_sequence + 1)
          else
            Map.put(coordinate, :intra_stop_sequence, 1)
          end

        [coordinate | acc]
    end)
    |> Enum.sort_by(& &1.dist_from_location, &<=/2)
    |> Enum.reduce([], fn
      coordinate, [] ->
        [coordinate]

      coordinate, [prior_coordinate | _] = acc ->
        if coordinate.next_station.code == prior_coordinate.next_station.code and
             coordinate.intra_stop_sequence > prior_coordinate.intra_stop_sequence do
          [coordinate | acc]
        else
          acc
        end
    end)
    |> Enum.reverse()
  end

  def get_closest_station(stations, coordinate) do
    stations
    |> Enum.map(fn station ->
      bearing = Geocalc.bearing(station, coordinate) |> Geocalc.radians_to_degrees()
      Map.put(station, :bearing, bearing)
    end)
    |> Enum.reduce_while(nil, fn
      station, nil ->
        {:cont, station}

      station, prior_station ->
        if abs(prior_station.bearing - station.bearing) > 100 do
          {:halt, station}
        else
          {:cont, station}
        end
    end)
  end

  def get_shape_coordinates(commute) do
    from(sc in Db.Model.ShapeCoordinate,
      join: s in assoc(sc, :shape),
      join: t in assoc(s, :trip),
      join: gct in subquery(get_complete_trip(commute)),
      on: gct.trip_id == t.id,
      order_by: sc.sequence,
      select: %{
        sequence: sc.sequence,
        lat: sc.lat,
        lon: sc.lon
      }
    )
    |> Db.Repo.all()
  end

  def get_complete_trip(%{route_code: code, direction: direction}) do
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

  def get_stations(commute) do
    from(s in Db.Model.Schedule,
      join: st in assoc(s, :station),
      join: t in assoc(s, :trip),
      join: gct in subquery(get_complete_trip(commute)),
      on: gct.trip_id == s.trip_id,
      order_by: s.sequence,
      select: %{
        id: st.id,
        code: st.code,
        name: st.name,
        depart_time: s.departure_time,
        sequence: s.sequence,
        lat: st.lat,
        lon: st.lon
      }
    )
    |> Db.Repo.all()
    |> put_trip_durations()
  end

  defp put_trip_durations(stations) do
    stations
    |> Enum.reduce([], fn
      station, [] ->
        station = Map.put(station, :prior_depart_time, station.depart_time)
        [station]

      station, [prior_station | _] = acc ->
        station = Map.put(station, :prior_depart_time, prior_station.depart_time)
        [station | acc]
    end)
    |> Enum.reverse()
    |> Enum.map(fn stop ->
      min = Time.diff(stop.depart_time, stop.prior_depart_time, :second) / 60
      Map.put(stop, :prior_station_min, round(min))
    end)
  end
end
