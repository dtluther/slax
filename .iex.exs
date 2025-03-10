import Ecto.Changeset
import Ecto.Query

alias Slax.Accounts
alias Slax.Accounts.User

alias Slax.Chat.{
  Message,
  Room,
  RoomMembership
}

alias Slax.Repo

IO.puts(".iex.exs loaded")
