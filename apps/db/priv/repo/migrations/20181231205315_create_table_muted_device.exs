defmodule Db.Repo.Migrations.CreateTableMutedDevice do
  use Ecto.Migration

  def change do
    create table("muted_device") do
      add :device_id, :string

      timestamps()
    end

    create unique_index("muted_device", [:device_id])
  end
end
