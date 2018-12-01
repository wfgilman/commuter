defmodule Db.Model.Station do
  use Ecto.Schema

  schema "station" do
    field(:code, :string)
    field(:name, Db.StationName)
    field(:lat, :float)
    field(:lon, :float)
    field(:url, :string)
    timestamps()
  end
end
