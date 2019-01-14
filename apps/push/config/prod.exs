use Mix.Config

config :pigeon,
  workers: [
    {Push.Pigeon, :apns_jwt}
  ]
