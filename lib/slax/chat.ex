defmodule Slax.Chat do
  alias Slax.Repo
  alias Slax.Chat.Room

  import Ecto.Query

  def get_first_room! do
    Room
    |> order_by([asc: :inserted_at])
    |> limit(1)
    |> Repo.one!
  end

  def get_room!(id) do
    Repo.get!(Room, id)
  end

  def list_rooms do
    Room
    |> order_by([asc: :name])
    |> Repo.all()
  end
end
