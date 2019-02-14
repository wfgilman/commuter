defmodule Db.Repo.Migrations.AlterTableTripAddShapeFk do
  use Ecto.Migration

  def change do
    alter table("trip") do
      add :shape_id, references(:shape)
    end

    create index("trip", [:shape_id])
  end
end
