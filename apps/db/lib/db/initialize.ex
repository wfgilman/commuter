defmodule Db.Initialize do
  import Ecto.Query

  @app :db
  @agency_file "agency.txt"
  @service_file "calendar_attributes.txt"
  @service_calendar_file "calendar.txt"
  @service_exception_file "calendar_dates.txt"
  @route_file "routes.txt"
  @station_file "stops.txt"
  @shape_file "shapes.txt"
  @trip_file "trips.txt"
  @schedule_file "stop_times.txt"

  NimbleCSV.define(MyParser, separator: ["\t", ","], new_lines: ["\r", "\r\n", "\n"])

  @doc """
  Load all GTFS data.
  """
  def load do
    load_agency()
    load_service()
    load_service_exception()
    load_route()
    load_station()
    load_shape()
    load_trip()
    load_schedule()
    Ecto.Adapters.SQL.query!(Db.Repo, "REFRESH MATERIALIZED VIEW trip_last_station")
  end

  @doc """
  Wipe existing GTFS data and reload.
  """
  def reload do
    Db.Repo.delete_all(Db.Model.Schedule)
    Db.Repo.delete_all(Db.Model.Trip)
    Db.Repo.delete_all(Db.Model.ShapeCoordinate)
    Db.Repo.delete_all(Db.Model.Shape)
    Db.Repo.delete_all(Db.Model.Station)
    Db.Repo.delete_all(Db.Model.Route)
    Db.Repo.delete_all(Db.Model.ServiceException)
    Db.Repo.delete_all(Db.Model.Service)
    Db.Repo.delete_all(Db.Model.Agency)
    load()
  end

  @doc """
  Load Agencies.
  """
  def load_agency do
    @agency_file
    |> file_path(@app)
    |> File.read!()
    |> MyParser.parse_string()
    |> Enum.map(fn [agency_id, agency_name, agency_url, agency_timezone, agency_lang, _agency_phone] ->
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
    |> Stream.map(fn [service_id, service_desc] ->
      %{
        code: service_id,
        name: service_desc
      }
    end)
    # Filter out any Oakland Int'l Airport services.
    |> Stream.reject(fn %{code: code} ->
        String.contains?(code, "OAC")
    end)
    |> Enum.each(fn param ->
      Db.Repo.insert!(struct(Db.Model.Service, param), on_conflict: :nothing)
    end)
  end

  @doc """
  Loads service calendar.
  """
  def load_service_calendar do
    services = Db.Repo.all(Db.Model.Service)

    @service_calendar_file
    |> file_path(@app)
    |> File.stream!()
    |> MyParser.parse_stream()
    |> Stream.map(fn [service_id, m, t, w, th, f, s, sun, date_effective] ->
      %{
        mon: to_boolean(m),
        tue: to_boolean(t),
        wed: to_boolean(w),
        thu: to_boolean(th),
        fri: to_boolean(f),
        sat: to_boolean(s),
        sun: to_boolean(sun),
        date_effective: date_from_string(date_effective),
        service_id: Enum.find(services, &(&1.code == service_id)).id
      }
    end)
    |> Enum.each(fn param ->
      Db.Repo.insert!(struct(Db.Model.ServiceCalendar, param), on_conflict: :nothing)
    end)
  end

  @doc """
  Loads service exceptions (holidays).
  """
  def load_service_exception do
    services = Db.Repo.all(Db.Model.Service)

    @service_exception_file
    |> file_path(@app)
    |> File.stream!()
    |> MyParser.parse_stream()
    |> Stream.map(fn [service_id, date, exception_type] ->
      %{
        date: date_from_string(date),
        service_id: Enum.find(services, &(&1.code == service_id)).id,
        exception_type: exception_type
      }
    end)
    |> Stream.reject(&(&1.exception_type == "2"))
    |> Enum.each(fn param ->
      Db.Repo.insert!(struct(Db.Model.ServiceException, param), on_conflict: :nothing)
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
  Load shapes.
  """
  def load_shape do
    @shape_file
    |> file_path(@app)
    |> File.stream!()
    |> MyParser.parse_stream()
    |> Stream.map(fn [shape_id, shape_pt_lat, shape_pt_lon, shape_pt_sequence] ->
      %{
        code: shape_id,
        lat: String.to_float(shape_pt_lat),
        lon: String.to_float(shape_pt_lon),
        sequence: String.to_integer(shape_pt_sequence)
      }
    end)
    |> Enum.reduce([], fn param, shapes ->
      shapes =
        case Enum.find(shapes, &(&1.code == param.code)) do
          nil ->
            shape = Db.Repo.insert!(struct(Db.Model.Shape, code: param.code))
            [shape | shapes]

          _ ->
            shapes
        end

      struct = %Db.Model.ShapeCoordinate{
        lat: param.lat,
        lon: param.lon,
        sequence: param.sequence,
        shape_id: Enum.find(shapes, &(&1.code == param.code)).id
      }

      Db.Repo.insert!(struct, on_conflict: :nothing)

      shapes
    end)

    :ok
  end

  @doc """
  Load trips.
  """
  def load_trip do
    routes = Db.Repo.all(Db.Model.Route)
    services = Db.Repo.all(Db.Model.Service)
    shapes = Db.Repo.all(Db.Model.Shape)

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
                       shape_id,
                       _wheelchair,
                       _bikes
                     ] ->
      %{
        code: trip_id,
        headsign: trip_headsign,
        direction: map_direction(direction_id),
        route_id: Enum.find(routes, &(&1.code == route_id)).id,
        service_id: Enum.find(services, &(&1.code == service_id)).id,
        shape_id: Enum.find(shapes, &(&1.code == shape_id)).id
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
    |> Enum.each(fn param ->
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

  def date_from_string(<<year::bytes-size(4), month::bytes-size(2), day::bytes-size(2)>>) do
    {:ok, date} =
      Date.new(String.to_integer(year), String.to_integer(month), String.to_integer(day))

    date
  end

  def standardize_time("24" <> time), do: "00" <> time
  def standardize_time("25" <> time), do: "01" <> time
  def standardize_time("26" <> time), do: "02" <> time
  def standardize_time(time), do: time

  defp to_boolean(0), do: false
  defp to_boolean(1), do: true
end
