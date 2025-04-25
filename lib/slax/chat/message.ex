defmodule Slax.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  alias Slax.Accounts.User
  alias Slax.Chat.Room

  schema "messages" do
    belongs_to :user, User
    belongs_to :room, Room

    field :body, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> dbg()
    |> cast(attrs, [:body])
    |> validate_required([:body])
  end
end
