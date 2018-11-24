defmodule Db.Model.Schedule do
  use Ecto.Schema

  schema "schedule" do
    field(:arrival_time, :time)
    field(:departure_time, :time)
    field(:sequence, :integer)
    field(:headsign, :string)
    belongs_to(:trip, Db.Model.Trip)
    belongs_to(:station, Db.Model.Station)
    timestamps()
  end
end
