defmodule Db.Initialize do
  @app :db
  @agency_file "agency.txt"
  @service_file "calendar.txt"

  NimbleCSV.define(MyParser, separator: ["\t", ","], new_lines: ["\r", "\r\n", "\n"])

  def load_agency do
    @agency_file
    |> file_path(@app)
    |> File.read!()
    |> MyParser.parse_string()
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
