defmodule Db.Model.TripLastStation do
  use Ecto.Schema

  @primary_key false
  schema "trip_last_station" do
    belongs_to(:trip, Db.Model.Trip)
    belongs_to(:station, Db.Model.Station)
  end
end
