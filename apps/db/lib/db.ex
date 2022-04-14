defmodule Db do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    :telemetry.attach(
      "appsignal-ecto",
      [:commuter, :repo, :query],
      &Appsignal.Ecto.handle_event/4,
      nil
    )

    children = [
      supervisor(Db.Repo, [])
    ]

    opts = [strategy: :one_for_one, name: Db.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
