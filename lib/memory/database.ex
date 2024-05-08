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

  def join_game_room(pid \\ __MODULE__, player_id) do
    GenServer.call(pid, {:join_game_room, player_id})
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
        check_open_emojis(board)
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
        {:join_game_room, player_id},
        _from,
        %{players: %{player_one: %{id: nil}}} = state
      ) do
    new_state = put_in(state, [:players, :player_one, :id], player_id)
    {:reply, new_state, new_state}
  end

  def handle_call({:join_game_room, player_id}, _from, state) do
    new_state = put_in(state, [:players, :player_two, :id], player_id)
    {:reply, new_state, new_state}
  end

  def handle_call(:reset, _from, state) do
    new_state = %{state | board: generate_game_board()}
    {:reply, new_state, new_state}
  end

  defp check_open_emojis(board) do
    open_emojis = board |> Enum.filter(fn {_id, {status, _}} -> status == :open end)

    case open_emojis do
      [{id1, {_, emoji}}, {id2, {_, emoji}}] ->
        # %{%{board | id1 => {:guessed, emoji}} | id2 => {:guessed, emoji}}
        board
        |> Map.update!(id1, fn {_status, emoji} -> {:guessed, emoji} end)
        |> Map.update!(id2, fn {_status, emoji} -> {:guessed, emoji} end)

      [{id1, {_, _}}, {id2, {_, _}}] ->
        board
        |> Map.updfate!(id1, fn {_status, emoji} -> {:hidden, emoji} end)
        |> Map.update!(id2, fn {_status, emoji} -> {:hidden, emoji} end)
    end
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
end
