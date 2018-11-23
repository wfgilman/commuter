defmodule Db.Model.Station do
  use Ecto.Schema

  schema "station" do
    field(:code, :string)
    field(:name, :string)
    field(:lat, :float)
    field(:lon, :float)
    field(:url, :string)
    timestamps()
  end
end
