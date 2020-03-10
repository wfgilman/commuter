defmodule Db.Repo.Migrations.AlterTableRouteAddDirection do
  use Ecto.Migration

  def change do
    alter table("route") do
      add :direction, :string
    end
  end
end
