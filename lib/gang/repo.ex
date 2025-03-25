defmodule Gang.Repo do
  use Ecto.Repo,
    otp_app: :gang,
    adapter: Ecto.Adapters.Postgres
end
