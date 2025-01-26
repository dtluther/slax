defmodule Slax.Chat do
  alias Slax.Accounts.User
  alias Slax.Repo
  alias Slax.Chat.{Message, Room, RoomMembership}

  import Ecto.Query

  @pubsub Slax.PubSub

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
    with {:ok, message} <-
           %Message{user: user, room: room}
           |> change_message(attrs)
           |> Repo.insert() do
      Phoenix.PubSub.broadcast!(@pubsub, topic(room.id), {:new_message, message})

      {:ok, message}
    end
  end

  def delete_message_for_user(%User{id: user_id}, id) do
    message = %Message{user_id: ^user_id} = Repo.get(Message, id)

    Repo.delete(message)

    Phoenix.PubSub.broadcast!(@pubsub, topic(message.room_id), {:deleted_message, message})
  end

  def subscribe_to_room(room) do
    Phoenix.PubSub.subscribe(@pubsub, topic(room.id))
  end

  def unsubscribe_from_room(room) do
    Phoenix.PubSub.unsubscribe(@pubsub, topic(room.id))
  end

  def topic(room_id), do: "chat_room:#{room_id}"

  def join_room!(room, user) do
    Repo.insert!(%RoomMembership{room: room, user: user})
  end

  def list_joined_rooms(user) do
    user
    |> Repo.preload(rooms: from(r in Room, order_by: r.name))
    |> Map.fetch!(:rooms)
  end

  def joined?(room, user) do
    RoomMembership
    |> where(room_id: ^room.id, user_id: ^user.id)
    |> Repo.exists?()
  end
end
