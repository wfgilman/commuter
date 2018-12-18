use Mix.Config

config :db, Db.Repo,
  url: "${DATABASE_URL}",
  database: "",
  ssl: true,
  pool_size: 10
