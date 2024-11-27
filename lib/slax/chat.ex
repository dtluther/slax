defmodule Slax.Chat do
  alias Slax.Repo
  alias Slax.Chat.{Message, Room}

  import Ecto.Query

  def get_first_room! do
    Room
    |> order_by(asc: :inserted_at)
    |> limit(1)
    |> Repo.one!()
  end

  def get_room!(id) do
    Repo.get!(Room, id)
  end

  def list_rooms do
    Room
    |> order_by(asc: :name)
    |> Repo.all()
  end

  def change_room(room, attrs \\ %{}) do
    Room.changeset(room, attrs)
  end

  def create_room(attrs) do
    %Room{}
    |> Room.changeset(attrs)
    |> Repo.insert()
  end

  def update_room(%Room{} = room, attrs) do
    room
    |> Room.changeset(attrs)
    |> Repo.update()
  end

  def list_messages_in_room(%Room{id: room_id}) do
    Message
    |> where([m], m.room_id == ^room_id)
    |> order_by([m], asc: :inserted_at, asc: :id)
    |> preload(:user)
    |> Repo.all()
  end

  defdelegate change_message(message, attrs \\ %{}), to: Message, as: :changeset

  def create_message(user, room, attrs) do
    %Message{user: user, room: room}
    |> change_message(attrs)
    |> Repo.insert()
  end
end
