defmodule Push do
  use Application

  def start(_start_type, _start_args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Push.Departure, [])
    ]

    opts = [strategy: :one_for_one, name: Push.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
