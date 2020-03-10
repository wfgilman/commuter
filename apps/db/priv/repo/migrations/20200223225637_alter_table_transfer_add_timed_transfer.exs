defmodule Db.Repo.Migrations.AlterTableTransferAddTimedTransfer do
  use Ecto.Migration

  def change do
    alter table("transfer") do
      add :timed_transfer, :boolean
    end
  end
end
