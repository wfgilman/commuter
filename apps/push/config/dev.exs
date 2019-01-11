use Mix.Config

config :pigeon, :apns,
  apns_default: %{
    key: {:push, "certs/AuthKey_D4WPZ39FN6.p8"},
    key_identifier: "D4WPZ39FN6",
    team_id: "QQ7F8UFQ5X",
    mode: :dev
  }
