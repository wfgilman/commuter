defmodule Db do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    Telemetry.attach(
      "appsignal-ecto",
      [:commuter, :repo, :query],
      Appsignal.Ecto,
      :handle_event,
      nil
    )

    children = [
      supervisor(Db.Repo, [])
    ]

    opts = [strategy: :one_for_one, name: Db.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
