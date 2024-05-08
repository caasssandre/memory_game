defmodule Memory.Database do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def open(pid \\ __MODULE__, emoji_id) do
    GenServer.call(pid, {:open, emoji_id})
  end

  def board(pid \\ __MODULE__) do
    GenServer.call(pid, :board)
  end

  def players(pid \\ __MODULE__) do
    GenServer.call(pid, :players)
  end

  def check_open_emojis(pid \\ __MODULE__, socket_id) do
    GenServer.call(pid, {:check_open_emojis, socket_id})
  end

  def join_game_room(pid \\ __MODULE__, socket_id) do
    GenServer.call(pid, {:join_game_room, socket_id})
  end

  def reset(pid \\ __MODULE__) do
    GenServer.call(pid, :reset)
  end

  def init(_opts) do
    {:ok, %{board: generate_game_board(), players: []}}
  end

  def handle_call({:open, emoji_id}, _from, %{board: board} = state) do
    new_board =
      if board |> Enum.filter(fn {_id, {status, _}} -> status == :open end) |> length() < 2 do
        Map.update!(board, String.to_integer(emoji_id), fn {_status, emoji} -> {:open, emoji} end)
      else
        board
      end

    new_state = %{state | board: new_board}

    {:reply, new_state, new_state}
  end

  def handle_call(:board, _from, state) do
    {:reply, state.board, state}
  end

  def handle_call(:players, _from, state) do
    {:reply, state.players, state}
  end

  def handle_call({:join_game_room, socket_id}, _from, %{players: []} = state) do
    new_players = %{id: socket_id, score: 0}
    new_state = %{state | players: [new_players]}

    {:reply, new_state, new_state}
  end

  def handle_call({:join_game_room, socket_id}, _from, %{players: [player_one | []]} = state) do
    new_players = [%{id: socket_id, score: 0}, player_one]
    new_state = %{state | players: new_players}

    {:reply, new_state, new_state}
  end

  def handle_call({:join_game_room, _socket_id}, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:reset, _from, state) do
    new_state =
      state
      |> Map.update!(:players, fn _ -> reset_players(state) end)
      |> Map.update!(:board, fn _ -> generate_game_board() end)

    {:reply, new_state, new_state}
  end

  def handle_call(
        {:check_open_emojis, socket_id},
        _from,
        %{board: board, players: players} = state
      ) do
    open_emojis = board |> Enum.filter(fn {_id, {status, _}} -> status == :open end)

    {new_players, new_board} =
      case open_emojis do
        [{id1, {_, emoji}}, {id2, {_, emoji}}] ->
          updated_board =
            board
            |> Map.update!(id1, fn {_status, emoji} -> {:guessed, emoji} end)
            |> Map.update!(id2, fn {_status, emoji} -> {:guessed, emoji} end)

          updated_players = inc_point(players, socket_id)
          {updated_players, updated_board}

        [{id1, {_, _}}, {id2, {_, _}}] ->
          updated_board =
            board
            |> Map.update!(id1, fn {_status, emoji} -> {:hidden, emoji} end)
            |> Map.update!(id2, fn {_status, emoji} -> {:hidden, emoji} end)

          {players, updated_board}

        _ ->
          {players, board}
      end

    new_state =
      state
      |> Map.update!(:players, fn _ -> new_players end)
      |> Map.update!(:board, fn _ -> new_board end)

    {:reply, new_state, new_state}
  end

  defp generate_game_board do
    emojis = ["😀", "😂", "😅", "😍", "😎", "😏", "😡", "🥳", "😭", "🤔", "🤩", "🤷"]
    # emojis = ["😀", "😂", "🤷"]

    (emojis ++ emojis)
    |> Enum.with_index()
    |> Enum.map(fn {em, i} -> {i, {:hidden, em}} end)
    |> Map.new()
  end

  defp reset_players(%{players: players}) do
    Enum.map(players, fn player -> %{id: player.id, score: 0} end)
  end

  defp inc_point(players, socket_id) do
    Enum.find_index(players, fn %{id: id, score: _} -> id == socket_id end)
    |> case do
      nil ->
        players

      index ->
        List.update_at(players, index, fn %{id: id, score: score} ->
          %{id: id, score: score + 1}
        end)
    end
  end
end
