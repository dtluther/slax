defmodule Slax.Chat do
  alias Slax.Accounts.User
  alias Slax.Repo
  alias Slax.Chat.{Message, Room, RoomMembership}

  import Ecto.Changeset
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
    # # could also define the query and pass it to preload instead of using from
    # query =
    #   Room
    #   |> order_by(asc: :name)
    #
    # user
    # |> Repo.preload(rooms: query)

    user
    |> Repo.preload(rooms: from(r in Room, order_by: r.name))
    |> Map.fetch!(:rooms)
  end

  def joined?(room, user) do
    RoomMembership
    |> where(room_id: ^room.id, user_id: ^user.id)
    |> Repo.exists?()
  end

  def list_rooms_with_joined(user) do
    # query =
    #   from r in Room,
    #     left_join: m in RoomMembership,
    #     on: r.id == m.room_id and m.user_id == ^user.id,
    #     select: {r, not is_nil(m.id)},
    #     order_by: [asc: :name]
    #
    # Repo.all(query)

    Room
    |> join(:left, [r], m in RoomMembership, on: r.id == m.room_id and ^user.id == m.user_id)
    |> select([r, m], {r, not is_nil(m.id)})
    |> order_by([r, _m], asc: r.name)
    |> Repo.all()
  end

  def toggle_room_membership(%Room{} = room, %User{} = user) do
    case get_membership(room, user) do
      nil ->
        join_room!(room, user)
        {room, true}

      membership ->
        Repo.delete!(membership)
        {room, false}
    end
  end

  def update_last_read_id(room, user) do
    case get_membership(room, user) do
      %RoomMembership{} = membership ->
        id =
          Message
          |> where(room_id: ^room.id)
          |> select([m], max(m.id))
          |> Repo.one()

        membership
        |> change(last_read_id: id)
        |> Repo.update()

      nil ->
        nil
    end
  end

  defp get_membership(room, user) do
    Repo.get_by(RoomMembership, room_id: room.id, user_id: user.id)
  end

  def get_last_read_id(%Room{} = room, user) do
    case get_membership(room, user) do
      %RoomMembership{} = membership -> membership.last_read_id
      nil -> nil
    end
  end
end
