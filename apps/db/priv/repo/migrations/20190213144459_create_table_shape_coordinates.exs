defmodule Db.Repo.Migrations.CreateTableShapeCoordinate do
  use Ecto.Migration

  def change do
    create table("shape_coordinate") do
      add :lat, :float
      add :lon, :float
      add :sequence, :integer
      add :shape_id, references(:shape)

      timestamps()
    end

    create index("shape_coordinate", [:shape_id])
  end
end
