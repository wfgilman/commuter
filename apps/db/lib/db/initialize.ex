defmodule Db.Initialize do
  @app :db
  @agency_file "agency.txt"
  @service_file "calendar.txt"
  @route_file "routes.txt"
  @station_file "stops.txt"

  NimbleCSV.define(MyParser, separator: ["\t", ","], new_lines: ["\r", "\r\n", "\n"])
  NimbleCSV.define(AgencyParser, separator: "\t", newlines: ["\r", "\r\n", "\n"])

  def load do
    load_agency()
    load_service()
    load_route()
    load_station()
  end

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
      Db.Repo.insert!(struct(Db.Model.Agency, param))
    end)
  end

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
      Db.Repo.insert!(struct(Db.Model.Service, param))
    end)
  end

  def load_route do
    agency = Db.Repo.get_by(Db.Model.Agency, code: "BART")

    @route_file
    |> file_path(@app)
    |> File.stream!()
    |> MyParser.parse_stream()
    |> Stream.map(fn [route_id, _agency_id, route_short_name, route_long_name, _route_desc, _route_type, route_url, route_color, _route_text_color] ->
      %{
        code: route_id,
        name: route_long_name,
        url: route_url,
        color: route_short_name,
        color_hex_code: route_color,
        agency_id: agency.id
      }
    end)
    |> Enum.each( fn param ->
      Db.Repo.insert!(struct(Db.Model.Route, param))
    end)
  end

  def load_station do
    @station_file
    |> file_path(@app)
    |> File.stream!()
    |> MyParser.parse_stream()
    |> Stream.map(fn [stop_id, stop_name, _stop_desc, stop_lat, stop_lon, _zone_id, stop_url, _loc_type, _parent_station, _stop_tz, _wheelchair] ->
      %{
        code: stop_id,
        name: stop_name,
        lat: String.to_float(stop_lat),
        lon: String.to_float(stop_lon),
        url: stop_url
      }
    end)
    |> Enum.map(fn param ->
      Db.Repo.insert!(struct(Db.Model.Station, param))
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
end
