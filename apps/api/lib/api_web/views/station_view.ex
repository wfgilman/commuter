defmodule ApiWeb.StationView do
  use ApiWeb, :view

  def render("index.json", %{data: stations}) do
    %{
      object: "station",
      data: Enum.map(stations, &Map.take(&1, [:code, :name]))
    }
  end
end
