defmodule Db.Repo.Migrations.CreateTableTransfer do
  use Ecto.Migration

  def change do
    create table("transfer") do
      add :station_id, references(:station, on_delete: :delete_all), null: false
      add :from_route_id, references(:route, on_delete: :delete_all), null: false
      add :to_route_id, references(:route, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index("transfer", [:station_id, :from_route_id, :to_route_id])
  end
end
