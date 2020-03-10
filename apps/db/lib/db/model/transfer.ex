defmodule Db.Model.Transfer do
  use Ecto.Schema

  schema "transfer" do
    belongs_to(:station, Db.Model.Station)
    belongs_to(:from_route, Db.Model.Route)
    belongs_to(:to_route, Db.Model.Route)
    field(:transfer_time_sec, :integer)
    field(:timed_transfer, :boolean)
    timestamps()
  end
end
