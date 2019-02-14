defmodule Db.Model.Shape do
  use Ecto.Schema

  schema "shape" do
    field(:code, :string)
    has_many(:trip, Db.Model.Trip)
    has_many(:shape_coordinate, Db.Model.ShapeCoordinate)
    timestamps()
  end
end
