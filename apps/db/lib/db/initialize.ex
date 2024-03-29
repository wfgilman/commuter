defmodule Db.Initialize do
  import Ecto.Query

  @app :db

  NimbleCSV.define(MyParser, separator: ["\t", ","], new_lines: ["\r", "\r\n", "\n"])

  @doc """
  Load all GTFS data.
  """
  def load do
    load_agency()
    load_service()
    load_service_calendar()
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
    # Notify users before wiping notifications.
    Push.Departure.reset_all_notifications()
    Db.Repo.delete_all(Db.Model.Schedule)
    Db.Repo.delete_all(Db.Model.Trip)
    Db.Repo.delete_all(Db.Model.ShapeCoordinate)
    Db.Repo.delete_all(Db.Model.Shape)
    Db.Repo.delete_all(Db.Model.Station)
    Db.Repo.delete_all(Db.Model.Route)
    Db.Repo.delete_all(Db.Model.ServiceException)
    Db.Repo.delete_all(Db.Model.ServiceCalendar)
    Db.Repo.delete_all(Db.Model.Service)
    Db.Repo.delete_all(Db.Model.Agency)
    load()
  end

  @doc """
  Load Agencies.
  """
  def load_agency do
    "agency.txt"
    |> file_path(@app)
    |> File.read!()
    |> MyParser.parse_string()
    |> Enum.map(fn [
                     agency_id,
                     agency_name,
                     agency_url,
                     agency_timezone,
                     agency_lang,
                     _agency_phone
                   ] ->
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
    |> then(&IO.puts("Loaded #{Enum.count(&1)} agencies."))
  end

  @doc """
  Load services.
  """
  def load_service do
    "calendar_attributes.txt"
    |> file_path(@app)
    |> File.stream!()
    |> MyParser.parse_stream()
    |> Stream.reject(fn [service_id, _service_desc] ->
      String.contains?(service_id, "OAC")
    end)
    |> Stream.map(fn [service_id, service_desc] ->
      %{
        code: service_id,
        name: service_desc
      }
    end)
    # Filter out any Oakland Int'l Airport services.
    |> Enum.reduce(0, fn param, acc ->
      Db.Repo.insert!(struct(Db.Model.Service, param), on_conflict: :nothing)
      acc + 1
    end)
    |> then(&IO.puts("Loaded #{&1} services."))
  end

  @doc """
  Loads service calendar.
  """
  def load_service_calendar do
    services = Db.Repo.all(Db.Model.Service)

    "calendar.txt"
    |> file_path(@app)
    |> File.stream!()
    |> MyParser.parse_stream()
    |> Stream.reject(fn [service_id, _m, _t, _w, _th, _f, _s, _sun, _sd, _ed] ->
      String.contains?(service_id, "OAC")
    end)
    |> Stream.map(fn [service_id, m, t, w, th, f, s, sun, start_date, _end_date] ->
      %{
        mon: to_boolean(m),
        tue: to_boolean(t),
        wed: to_boolean(w),
        thu: to_boolean(th),
        fri: to_boolean(f),
        sat: to_boolean(s),
        sun: to_boolean(sun),
        date_effective: date_from_string(start_date),
        service_id: Enum.find(services, &(&1.code == service_id)).id
      }
    end)
    |> Enum.reduce(0, fn param, acc ->
      Db.Repo.insert!(struct(Db.Model.ServiceCalendar, param), on_conflict: :nothing)
      acc + 1
    end)
    |> then(&IO.puts("Loaded #{&1} service calendars."))
  end

  @doc """
  Loads service exceptions (holidays).
  """
  def load_service_exception do
    services = Db.Repo.all(Db.Model.Service)

    "calendar_dates.txt"
    |> file_path(@app)
    |> File.stream!()
    |> MyParser.parse_stream()
    |> Stream.reject(fn [service_id, _d, _et] ->
      String.contains?(service_id, "OAC")
    end)
    |> Stream.map(fn [service_id, date, exception_type] ->
      %{
        date: date_from_string(date),
        service_id: Enum.find(services, &(&1.code == service_id)).id,
        exception_type: exception_type
      }
    end)
    |> Stream.reject(&(&1.exception_type == "2"))
    |> Enum.reduce(0, fn param, acc ->
      Db.Repo.insert!(struct(Db.Model.ServiceException, param), on_conflict: :nothing)
      acc + 1
    end)
    |> then(&IO.puts("Loaded #{&1} service exceptions."))
  end

  @doc """
  Load routes.
  """
  def load_route do
    agency = Db.Repo.get_by(Db.Model.Agency, code: "BART")

    "routes.txt"
    |> file_path(@app)
    |> File.stream!()
    |> MyParser.parse_stream()
    |> Stream.map(fn [
                       route_id,
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
    |> Enum.reduce(0, fn param, acc ->
      Db.Repo.insert!(struct(Db.Model.Route, param), on_conflict: :nothing)
      acc + 1
    end)
    |> then(&IO.puts("Loaded #{&1} routes."))
  end

  @doc """
  Load stations.
  """
  def load_station do
    "stops.txt"
    |> file_path(@app)
    |> File.stream!()
    |> MyParser.parse_stream()
    |> Stream.filter(fn [
                          _stop_id,
                          _stop_code,
                          _stop_name,
                          _stop_desc,
                          _stop_lat,
                          _stop_lon,
                          _zone_id,
                          _stop_url,
                          loc_type,
                          _parent_station
                        ] ->
      loc_type == "0"
    end)
    |> Stream.map(fn [
                       stop_id,
                       _stop_code,
                       stop_name,
                       _stop_desc,
                       stop_lat,
                       stop_lon,
                       _zone_id,
                       stop_url,
                       _loc_type,
                       _parent_station
                     ] ->
      %{
        code: stop_id,
        name: stop_name,
        lat: String.to_float(stop_lat),
        lon: String.to_float(stop_lon),
        url: stop_url
      }
    end)
    |> Enum.reduce(0, fn param, acc ->
      Db.Repo.insert!(struct(Db.Model.Station, param), on_conflict: :nothing)
      acc + 1
    end)
    |> then(&IO.puts("Loaded #{&1} stations."))
  end

  @doc """
  Load shapes.
  """
  def load_shape do
    "shapes.txt"
    |> file_path(@app)
    |> File.stream!()
    |> MyParser.parse_stream()
    |> Stream.map(fn [
                       shape_id,
                       shape_pt_lat,
                       shape_pt_lon,
                       shape_pt_sequence,
                       _shape_dist_traveled
                     ] ->
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
    |> then(&IO.puts("Loaded #{Enum.count(&1)} shapes."))
  end

  @doc """
  Load trips.
  """
  def load_trip do
    routes = Db.Repo.all(Db.Model.Route)
    services = Db.Repo.all(Db.Model.Service)
    shapes = Db.Repo.all(Db.Model.Shape)

    "trips.txt"
    |> file_path(@app)
    |> File.stream!()
    |> MyParser.parse_stream()
    |> Stream.reject(fn [
                          _route_id,
                          service_id,
                          _trip_id,
                          _trip_headsign,
                          _direction_id,
                          _block_id,
                          _shape_id,
                          _trip_load_information,
                          _wheelchair_accessible,
                          _bikes_allowed
                        ] ->
      String.contains?(service_id, "OAC")
    end)
    |> Stream.map(fn [
                       route_id,
                       service_id,
                       trip_id,
                       trip_headsign,
                       direction_id,
                       _block_id,
                       shape_id,
                       _trip_load_information,
                       _wheelchair_accessible,
                       _bikes_allowed
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
    |> Enum.reduce(0, fn param, acc ->
      Db.Repo.insert!(struct(Db.Model.Trip, param), on_conflict: :nothing)
      acc + 1
    end)
    |> then(&IO.puts("Loaded #{&1} trips."))
  end

  @doc """
  Load schedules.
  """
  def load_schedule do
    trips =
      Db.Repo.all(from(t in Db.Model.Trip, join: s in assoc(t, :service), preload: [service: s]))

    stations = Db.Repo.all(Db.Model.Station)

    "stop_times.txt"
    |> file_path(@app)
    |> File.stream!()
    |> MyParser.parse_stream()
    |> Enum.reduce([], fn [
                            trip_id,
                            arrival_time,
                            depart_time,
                            stop_id,
                            stop_sequence,
                            _pickup_type,
                            _dropoff_type,
                            _shape_dist_traveled
                          ],
                          acc ->
      case Enum.find(trips, &(&1.code == trip_id)) do
        nil ->
          acc

        trip ->
          sched = %{
            arrival_time: Time.from_iso8601!(standardize_time(arrival_time)),
            departure_time: Time.from_iso8601!(standardize_time(depart_time)),
            sequence: String.to_integer(stop_sequence),
            headsign: trip.headsign,
            arrival_day_offset: day_offset(arrival_time),
            departure_day_offset: day_offset(depart_time),
            trip_id: trip.id,
            station_id: Enum.find(stations, &(&1.code == stop_id)).id
          }

          [sched | acc]
      end
    end)
    |> Enum.reduce(0, fn param, acc ->
      Db.Repo.insert!(struct(Db.Model.Schedule, param), on_conflict: :nothing)
      acc + 1
    end)
    |> then(&IO.puts("Loaded #{&1} schedules."))
  end

  defp priv_dir(app), do: "#{:code.priv_dir(app)}"

  defp file_path(filename, app), do: Path.join([priv_dir(app), "gtfs", "bart", filename])

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

  def standardize_time(time) do
    if String.length(time) == 7 do
      "0" <> time
    else
      time
    end
  end

  defp day_offset("24" <> _), do: 1
  defp day_offset("25" <> _), do: 1
  defp day_offset("26" <> _), do: 1
  defp day_offset(_), do: 0

  defp to_boolean("0"), do: false
  defp to_boolean("1"), do: true
end
