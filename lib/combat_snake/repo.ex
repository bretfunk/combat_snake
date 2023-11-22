defmodule CombatSnake.Repo do
  use Ecto.Repo,
    otp_app: :combat_snake,
    adapter: Ecto.Adapters.Postgres
end
