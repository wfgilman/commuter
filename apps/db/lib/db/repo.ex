defmodule Db.Repo do
  use Ecto.Repo,
    otp_app: :db,
    adapter: Ecto.Adapters.Postgres
end
