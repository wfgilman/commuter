defmodule Db.Repo.Migrations.CreateTableSchedule do
  use Ecto.Migration

  def change do
    create table("schedule") do
      add :arrival_time, :time
      add :departure_time, :time
      add :sequence, :integer
      add :headsign, :string
      add :trip_id, references(:trip)
      add :station_id, references(:station)

      timestamps()
    end

    create unique_index("schedule", [:trip_id, :station_id])
    create index("schedule", [:trip_id])
    create index("schedule", [:station_id])
  end
end
