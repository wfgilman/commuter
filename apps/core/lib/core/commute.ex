defmodule Core.Commute do
  import Ecto.Query

  defstruct [:route_code, :route_name, :direction, :orig_station_code, :dest_station_code]

  @type t :: %__MODULE__{
          route_code: String.t(),
          route_name: String.t(),
          direction: String.t(),
          orig_station_code: String.t(),
          dest_station_code: String.t()
        }

  @doc """
  Get route and direction based on start and end station. Excludes transfers.
  """
  @spec get(String.t(), String.t()) :: [Core.Commute.t()]
  def get(orig_station, dest_station) do
    from(t in Db.Model.Trip,
      join: r in assoc(t, :route),
      join: ss in subquery(trips_through_station(orig_station)),
      on: ss.trip_id == t.id,
      join: es in subquery(trips_through_station(dest_station)),
      on: es.trip_id == t.id,
      where: ss.sequence < es.sequence,
      distinct: true,
      select: %{
        route_code: r.code,
        route_name: r.name,
        direction: t.direction,
        orig_station_code: ^orig_station,
        dest_station_code: ^dest_station
      }
    )
    |> Db.Repo.all()
    |> Enum.map(&struct(__MODULE__, &1))
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

  defp direct_routes(orig_station, dest_station) do
    from(r in Db.Model.Route,
      join: rs1 in assoc(r, :route_station),
      join: s1 in assoc(rs1, :station),
      join: rs2 in assoc(r, :route_station),
      join: s2 in assoc(rs2, :station),
      where: s1.code == ^orig_station,
      where: s2.code == ^dest_station,
      where: rs1.sequence < rs2.sequence
    )
  end

  defp get_direct_routes(orig_station, dest_station) do
    Db.Repo.all(direct_routes(orig_station, dest_station))
  end

  # 1. Find all routes running through a station.
  defp routes_through_station(station) do
    from(rs in Db.Model.RouteStation,
      join: s in assoc(rs, :station),
      where: s.code == ^station,
      select: %{
        route_id: rs.route_id,
        sequence: rs.sequence
      }
    )
  end

  # 2. Find all transfer stations downstream on routes from origin station.
  defp transfer_stations_downstream(station) do
    from(s in Db.Model.Station,
      join: rs in Db.Model.RouteStation,
      on: rs.station_id == s.id,
      join: rts in subquery(routes_through_station(station)),
      on: rts.route_id == rs.route_id,
      left_join: t in Db.Model.Transfer,
      on: rs.route_id == t.from_route_id and rs.station_id == t.station_id,
      where: rs.sequence > rts.sequence,
      where: not is_nil(t.id),
      distinct: true,
      select: s
    )
  end

  # 3. Select all transfer stations that are upstream from destination station.
  defp transfer_stations_upstream(origin, destination) do
    from(s in Db.Model.Station,
      join: rs in Db.Model.RouteStation,
      on: rs.station_id == s.id,
      join: rts in subquery(routes_through_station(destination)),
      on: rts.route_id == rs.route_id,
      join: us in subquery(transfer_stations_downstream(origin)),
      on: us.id == rs.station_id,
      left_join: t in Db.Model.Transfer,
      on: rs.route_id == t.from_route_id and rs.station_id == t.station_id,
      where: not is_nil(t.id),
      distinct: true,
      select: s
    )
  end

  # 4. Select transfer station with minimum number of stops.
  @spec transfer_station_with_min_stops(String.t(), String.t()) :: Db.Model.Station.t() | nil
  def transfer_station_with_min_stops(origin, destination) do
    transfer_stations = Db.Repo.all(transfer_stations_upstream(origin, destination))
    direct_route = List.first(get_direct_routes(origin, destination))

    stops =
      from(rs in Db.Model.RouteStation,
        join: s in assoc(rs, :station),
        join: r in assoc(rs, :route),
        preload: [station: s, route: r],
        order_by: rs.sequence
      )
      |> Db.Repo.all()

    transfer_stations
    |> Enum.map(fn station ->
      %{
        transfer_station: station,
        upstream_route: List.first(get_direct_routes(origin, station.code))
      }
    end)
    |> Enum.map(fn %{transfer_station: station} = result ->
      Map.put(result, :downstream_route, List.first(get_direct_routes(station.code, destination)))
    end)
    # Reject all transfer stations where the transfer doesn't change the route.
    |> Enum.reject(fn result ->
      result.transfer_station.code == destination or
        result.upstream_route.code == result.downstream_route.code
    end)
    |> Enum.map(fn %{transfer_station: station} = result ->
      Map.put(
        result,
        :upstream_stops,
        count_stops_between_stations_on_same_route(
          stops,
          result.upstream_route,
          origin,
          station.code
        )
      )
    end)
    |> Enum.map(fn %{transfer_station: station} = result ->
      Map.put(
        result,
        :downstream_stops,
        count_stops_between_stations_on_same_route(
          stops,
          result.downstream_route,
          station.code,
          destination
        )
      )
    end)
    |> Enum.map(fn result ->
      total_stops = result.upstream_stops + result.downstream_stops

      %{
        transfer_station: result.transfer_station,
        total_stops: total_stops
      }
    end)
    # Reject all transfer stations where the trip length is longer than taking a direct route, if direct route exists.
    |> Enum.reject(fn result ->
      with true <- not is_nil(direct_route),
           true <-
             result.total_stops >
               count_stops_between_stations_on_same_route(
                 stops,
                 direct_route,
                 origin,
                 destination
               ) do
        true
      end
    end)
    |> Enum.sort_by(& &1.total_stops)
    |> List.first()
    |> case do
      nil ->
        nil

      result ->
        Map.get(result, :transfer_station)
    end
  end

  defp count_stops_between_stations_on_same_route(_stops, _route, orig, dest) when orig == dest,
    do: 0

  defp count_stops_between_stations_on_same_route(stops, route, origin, destination) do
    route_stops = Enum.filter(stops, &(&1.route.code == route.code))
    orig_seq = get_station_sequence_on_route(route_stops, origin)
    dest_seq = Enum.find(route_stops, &(&1.station.code == destination)).sequence

    route_stops
    |> Enum.reject(fn stop ->
      stop.sequence <= orig_seq or stop.sequence > dest_seq
    end)
    |> Enum.count()
  end

  defp get_station_sequence_on_route(stops, station) do
    case Enum.find(stops, &(&1.station.code == station)) do
      nil ->
        IO.puts("Couldn't find station #{station}")
        nil

      stop ->
        stop.sequence
    end
  end
end
