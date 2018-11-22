use Mix.Config

config :db, ecto_repos: [Db.Repo]

import_config "#{Mix.env()}.exs"
