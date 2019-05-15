defmodule Db.Model.RouteStation do
  use Ecto.Schema

  schema "route_station" do
    belongs_to :route, Db.Model.Route
    belongs_to :station, Db.Model.Station
    field :sequence, :integer
    timestamps()
  end
end
