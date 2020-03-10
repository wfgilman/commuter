defmodule Db.Repo.Migrations.AlterTableTripRemoveDirection do
  use Ecto.Migration

  def change do
    alter table("trip") do
      remove :direction
    end
  end
end
