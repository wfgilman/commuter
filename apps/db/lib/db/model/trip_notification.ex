defmodule Db.Model.TripNotification do
  use Ecto.Schema

  schema "trip_notification" do
    field(:device_id, :string)
    belongs_to(:trip, Db.Model.Trip)
    timestamps()
  end
end
