defmodule Db.Repo.Migrations.CreateTableTripNotification do
  use Ecto.Migration

  def change do
    create table("trip_notification") do
      add :device_id, :string
      add :trip_id, references(:trip, on_delete: :delete_all)

      timestamps()
    end

    create unique_index("trip_notification", [:device_id, :trip_id])
    create index("trip_notification", [:trip_id])
  end
end
