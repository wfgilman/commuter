defmodule Db.Model.Station do
  use Ecto.Schema
  
  schema "station" do
    field :code, :string
    field :name, :string
    field :lat, :decimal
    field :lon, :decimal
    field :url, :decimal
  end
end
