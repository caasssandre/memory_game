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
    {:ok, %{board: generate_game_board(), players: players_map()}}
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

  def handle_call(
        {:join_game_room, socket_id},
        _from,
        %{players: %{player_one: %{id: nil}}} = state
      ) do
    new_state = put_in(state, [:players, :player_one, :id], socket_id)
    {:reply, new_state, new_state}
  end

  def handle_call({:join_game_room, socket_id}, _from, state) do
    new_state = put_in(state, [:players, :player_two, :id], socket_id)
    {:reply, new_state, new_state}
  end

  def handle_call(:reset, _from, state) do
    new_state =
      state
      |> Map.update!(:players, fn _ -> players_map() end)
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
    # emojis = ["😀", "😂", "😅", "😍", "😎", "😏", "😡", "🥳", "😭", "🤔", "🤩", "🤷"]
    emojis = ["😀", "😂", "🤷"]

    (emojis ++ emojis)
    |> Enum.with_index()
    |> Enum.map(fn {em, i} -> {i, {:hidden, em}} end)
    |> Enum.shuffle()
    |> Map.new()
  end

  defp players_map do
    %{
      player_one: %{id: nil, score: 0},
      player_two: %{id: nil, score: 0}
    }
  end

  defp inc_point(players, socket_id) do
    [{identifier, _player}] =
      Enum.filter(players, fn {_, %{id: id, score: _}} -> id == socket_id end)

    Map.update!(players, identifier, fn %{id: id, score: score} -> %{id: id, score: score + 1} end)
  end
end
