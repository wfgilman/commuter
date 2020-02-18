defmodule Db.Repo.Migrations.AlterTableScheduleAddDayOffset do
  use Ecto.Migration

  def change do
    alter table("schedule") do
      add :arrival_day_offset, :integer
      add :departure_day_offset, :integer
    end
  end
end
