defmodule Db.Repo.Migrations.CreateTableRouteStation do
  use Ecto.Migration

  def change do
    create table("route_station") do
      add :route_id, references(:route, on_delete: :delete_all), null: false
      add :station_id, references(:station, on_delete: :delete_all), null: false
      add :sequence, :integer
      timestamps()
    end

    create unique_index("route_station", [:route_id, :station_id])
  end
end
