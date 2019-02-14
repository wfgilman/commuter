defmodule Db.Model.Trip do
  use Ecto.Schema

  schema "trip" do
    field(:code, :string)
    field(:headsign, :string)
    field(:direction, :string)
    belongs_to(:route, Db.Model.Route)
    belongs_to(:service, Db.Model.Service)
    has_one(:trip_last_station, Db.Model.TripLastStation)
    belongs_to(:shape, Db.Model.Shape)
    timestamps()
  end
end
