defmodule Db.Initialize do

  @app :db
  @agency_file "agency.txt"

  NimbleCSV.define(MyParser, separator: "\t", new_lines: ["\r"])

  def load_agency do
    @agency_file
    |> file_path(@app)
    |> File.stream!()
    |> MyParser.parse_stream()
    |> Stream.map(fn([agency_id, agency_name, agency_url, agency_timezone, agency_lang]) ->
        %{code: agency_id, name: agency_name, url: agency_url, timezone: agency_timezone, lang: agency_lang}
      end)
    |> Enum.map(fn(param) ->
        IO.inspect(struct(Db.Model.Agency, param))
      end)
  end

  defp priv_dir(app), do: "#{:code.priv_dir(app)}"
  defp file_path(filename, app), do: Path.join([priv_dir(app), "gtfs", "bart", filename])

end
