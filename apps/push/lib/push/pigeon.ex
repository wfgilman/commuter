defmodule Push.Pigeon do
  def apns_jwt do
    Pigeon.APNS.JWTConfig.new(
      name: :apns_default,
      key: System.get_env("APNS_JWT_KEY"),
      key_identifier: System.get_env("APNS_JWT_KEY_IDENTIFIER"),
      team_id: System.get_env("APNS_JWT_TEAM_ID"),
      mode: :dev
    )
  end
end
