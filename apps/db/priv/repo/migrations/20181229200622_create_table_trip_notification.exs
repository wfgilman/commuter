defmodule Db.Repo.Migrations.CreateTableTripNotification do
  use Ecto.Migration

  def change do
    create table("trip_notification") do
      add :device_id, :string
      add :trip_id, references(:trip, on_delete: :delete_all)
      add :station_id, references(:station, on_delete: :delete_all)

      timestamps()
    end

    create unique_index("trip_notification", [:device_id, :trip_id, :station_id])
    create index("trip_notification", [:trip_id])
    create index("trip_notification", [:station_id])
  end
end
