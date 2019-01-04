defmodule Db.Repo.Migrations.CreateTableTripNotification do
  use Ecto.Migration

  def up do
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

  def down do
    drop table("trip_notification")
    drop_if_exists index("trip_notification", [:trip_id])
    drop_if_exists index("trip_notification", [:station_id])
    drop_if_exists unique_index("trip_notification", [:device_id, :trip_id])
  end
end
