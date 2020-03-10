defmodule Db.Model.Station do
  use Ecto.Schema

  schema "station" do
    field(:code, :string)
    field(:name, Db.StationName)
    field(:lat, :float)
    field(:lon, :float)
    field(:url, :string)
    field(:timed_transfer, :boolean, virtual: true)
    has_many(:route_station, Db.Model.RouteStation)
    timestamps()
  end
end
