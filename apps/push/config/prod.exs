use Mix.Config

config :pigeon, :apns,
  apns_default: %{
    key: "${APNS_KEY}",
    key_identifier: "D4WPZ39FN6",
    team_id: "QQ7F8UFQ5X",
    mode: :prod
  }
