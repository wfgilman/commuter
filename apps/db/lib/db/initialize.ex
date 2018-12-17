defmodule Db.Initialize do
  import Ecto.Query

  @app :db
  @agency_file "agency.txt"
  @service_file "calendar.txt"
  @route_file "routes.txt"
  @station_file "stops.txt"
  @trip_file "trips.txt"
  @schedule_file "stop_times.txt"

  NimbleCSV.define(MyParser, separator: ["\t", ","], new_lines: ["\r", "\r\n", "\n"])
  NimbleCSV.define(AgencyParser, separator: "\t", newlines: ["\r", "\r\n", "\n"])

  @doc """
  Load all GTFS data.
  """
  def load do
    load_agency()
    load_service()
    load_route()
    load_station()
    load_trip()
    load_schedule()
  end

  @doc """
  Load Agencies.
  """
  def load_agency do
    @agency_file
    |> file_path(@app)
    |> File.read!()
    |> AgencyParser.parse_string()
    |> Enum.map(fn [agency_id, agency_name, agency_url, agency_timezone, agency_lang] ->
      %{
        code: agency_id,
        name: agency_name,
        url: agency_url,
        timezone: agency_timezone,
        lang: agency_lang
      }
    end)
    |> Enum.map(fn param ->
      Db.Repo.insert!(struct(Db.Model.Agency, param), on_conflict: :nothing)
    end)
  end

  @doc """
  Load services.
  """
  def load_service do
    @service_file
    |> file_path(@app)
    |> File.stream!()
    |> MyParser.parse_stream()
    |> Stream.map(fn [service_id, _m, _t, _w, _th, _f, _s, _sun, _sd, _ed] ->
      %{
        code: service_id,
        name: map_service_code_to_name(service_id)
      }
    end)
    |> Enum.each(fn param ->
      Db.Repo.insert!(struct(Db.Model.Service, param), on_conflict: :nothing)
    end)
  end

  @doc """
  Load routes.
  """
  def load_route do
    agency = Db.Repo.get_by(Db.Model.Agency, code: "BART")

    @route_file
    |> file_path(@app)
    |> File.stream!()
    |> MyParser.parse_stream()
    |> Stream.map(fn [
                       route_id,
                       _agency_id,
                       route_short_name,
                       route_long_name,
                       _route_desc,
                       _route_type,
                       route_url,
                       route_color,
                       _route_text_color
                     ] ->
      %{
        code: route_id,
        name: route_long_name,
        url: route_url,
        color: route_short_name,
        color_hex_code: route_color,
        agency_id: agency.id
      }
    end)
    |> Enum.each(fn param ->
      Db.Repo.insert!(struct(Db.Model.Route, param), on_conflict: :nothing)
    end)
  end

  @doc """
  Load stations.
  """
  def load_station do
    @station_file
    |> file_path(@app)
    |> File.stream!()
    |> MyParser.parse_stream()
    |> Stream.map(fn [
                       stop_id,
                       stop_name,
                       _stop_desc,
                       stop_lat,
                       stop_lon,
                       _zone_id,
                       stop_url,
                       _loc_type,
                       _parent_station,
                       _stop_tz,
                       _wheelchair
                     ] ->
      %{
        code: stop_id,
        name: stop_name,
        lat: String.to_float(stop_lat),
        lon: String.to_float(stop_lon),
        url: stop_url
      }
    end)
    |> Enum.each(fn param ->
      Db.Repo.insert!(struct(Db.Model.Station, param), on_conflict: :nothing)
    end)
  end

  @doc """
  Load trips.
  """
  def load_trip do
    routes = Db.Repo.all(Db.Model.Route)
    services = Db.Repo.all(Db.Model.Service)

    @trip_file
    |> file_path(@app)
    |> File.stream!()
    |> MyParser.parse_stream()
    |> Stream.map(fn [
                       route_id,
                       service_id,
                       <<trip_id::bytes-size(7), _::binary>>,
                       trip_headsign,
                       direction_id,
                       _block_id,
                       _shape_id,
                       _wheelchair,
                       _bikes
                     ] ->
      %{
        code: trip_id,
        headsign: trip_headsign,
        direction: map_direction(direction_id),
        route_id: Enum.find(routes, &(&1.code == route_id)).id,
        service_id: Enum.find(services, &(&1.code == service_id)).id
      }
    end)
    |> Enum.each(fn param ->
      Db.Repo.insert!(struct(Db.Model.Trip, param), on_conflict: :nothing)
    end)
  end

  @doc """
  Load schedules.
  """
  def load_schedule do
    trips =
      Db.Repo.all(from(t in Db.Model.Trip, join: s in assoc(t, :service), preload: [service: s]))

    stations = Db.Repo.all(Db.Model.Station)

    @schedule_file
    |> file_path(@app)
    |> File.stream!()
    |> MyParser.parse_stream()
    |> Stream.map(fn [
                       <<trip_id::bytes-size(7), service_id::binary>>,
                       arrival_time,
                       depart_time,
                       stop_id,
                       stop_sequence,
                       stop_headsign,
                       _pickup,
                       _dropoff,
                       _shape,
                       _timepoint
                     ] ->
      %{
        arrival_time: Time.from_iso8601!(standardize_time(arrival_time)),
        departure_time: Time.from_iso8601!(standardize_time(depart_time)),
        sequence: String.to_integer(stop_sequence),
        headsign: stop_headsign,
        trip_id: Enum.find(trips, &(&1.code == trip_id and &1.service.code == service_id)).id,
        station_id: Enum.find(stations, &(&1.code == stop_id)).id
      }
    end)
    |> Enum.map(fn param ->
      IO.inspect(param)
      Db.Repo.insert!(struct(Db.Model.Schedule, param), on_conflict: :nothing)
    end)
  end

  defp priv_dir(app), do: "#{:code.priv_dir(app)}"

  defp file_path(filename, app), do: Path.join([priv_dir(app), "gtfs", "bart", filename])

  defp map_service_code_to_name(code) do
    case code do
      "WKDY" -> "Weekday"
      "SAT" -> "Saturday"
      "SUN" -> "Sunday"
    end
  end

  defp map_direction("0"), do: "South"
  defp map_direction("1"), do: "North"

  def standardize_time("24" <> time), do: "00" <> time
  def standardize_time("25" <> time), do: "01" <> time
  def standardize_time("26" <> time), do: "02" <> time
  def standardize_time(time), do: time
end
