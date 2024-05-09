defmodule Memory.Database do
  use GenServer

  def start_link(_opts), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  def open(pid \\ __MODULE__, emoji_id), do: GenServer.call(pid, {:open, emoji_id})
  def check_open_emojis(pid \\ __MODULE__), do: GenServer.call(pid, :check_open_emojis)
  def board(pid \\ __MODULE__), do: GenServer.call(pid, :board)
  def players(pid \\ __MODULE__), do: GenServer.call(pid, :players)
  def current_player(pid \\ __MODULE__), do: GenServer.call(pid, :current_player)
  def join_game_room(pid \\ __MODULE__), do: GenServer.call(pid, :join_game_room)
  def reset(pid \\ __MODULE__), do: GenServer.call(pid, :reset)

  def init(_opts) do
    {:ok, %{board: generate_game_board(), players: [], current_player: 0}}
  end

  def handle_call(:board, _from, state), do: {:reply, state.board, state}
  def handle_call(:players, _from, state), do: {:reply, Enum.reverse(state.players), state}
  def handle_call(:current_player, _from, state), do: {:reply, state.current_player, state}

  def handle_call(:join_game_room, _from, %{players: []} = state) do
    new_players = %{id: 1, score: 0}
    new_state = %{state | players: [new_players]}

    {:reply, 1, new_state}
  end

  def handle_call(:join_game_room, _from, %{players: [player_one | []]} = state) do
    new_players = [%{id: 2, score: 0}, player_one]
    new_state = %{state | players: new_players}

    {:reply, 2, new_state}
  end

  def handle_call(:join_game_room, _from, state) do
    {:reply, 0, state}
  end

  def handle_call(:reset, _from, state) do
    new_state =
      state
      |> Map.update!(:players, fn _ -> [] end)
      |> Map.update!(:board, fn _ -> generate_game_board() end)
      |> Map.update!(:current_player, fn _ -> 0 end)

    {:reply, new_state, new_state}
  end

  def handle_call({:open, emoji_id}, _from, %{board: board} = state) do
    open_emojis = board |> Enum.filter(fn {_id, {status, _}} -> status == :open end)

    new_board =
      cond do
        length(open_emojis) == 0 ->
          List.update_at(board, String.to_integer(emoji_id), fn {id, {_status, emoji}} ->
            {id, {:open, emoji}}
          end)

        length(open_emojis) == 1 ->
          List.update_at(board, String.to_integer(emoji_id), fn {id, {_status, emoji}} ->
            {id, {:open, emoji}}
          end)

        true ->
          board
      end

    new_state = %{state | board: new_board}
    {:reply, new_state, new_state}
  end

  def handle_call(
        :check_open_emojis,
        _from,
        %{board: board, players: players, current_player: current_player} = state
      ) do
    open_emojis = board |> Enum.filter(fn {_id, {status, _}} -> status == :open end)

    {outcome, new_players, new_board, new_current_player} =
      case open_emojis do
        [{id1, {_, emoji}}, {id2, {_, emoji}}] ->
          updated_board =
            board
            |> List.update_at(id1, fn {id, {_status, emoji}} -> {id, {:guessed, emoji}} end)
            |> List.update_at(id2, fn {id, {_status, emoji}} -> {id, {:guessed, emoji}} end)

          updated_players = inc_point(players, current_player + 1)

          if(updated_board |> Enum.all?(fn {_id, {status, _}} -> status == :guessed end)) do
            {:game_over, updated_players, updated_board, current_player}
          else
            {:good_guess, updated_players, updated_board, current_player}
          end

        [{id1, {_, _}}, {id2, {_, _}}] ->
          updated_board =
            board
            |> List.update_at(id1, fn {id, {_status, emoji}} -> {id, {:hidden, emoji}} end)
            |> List.update_at(id2, fn {id, {_status, emoji}} -> {id, {:hidden, emoji}} end)

          {:no_guess, players, updated_board, (current_player + 1) |> rem(2)}

        _ ->
          {:no_guess, players, board, current_player}
      end

    new_state =
      state
      |> Map.update!(:players, fn _ -> new_players end)
      |> Map.update!(:board, fn _ -> new_board end)
      |> Map.update!(:current_player, fn _ -> new_current_player end)

    {:reply, outcome, new_state}
  end

  defp generate_game_board do
    # emojis = ["😀", "😂", "😅", "😍", "😎", "😏", "😡", "🥳", "😭", "🤔", "🤩", "🤷"]
    emojis = ["😀", "😂", "🤷"]

    (emojis ++ emojis)
    |> Enum.shuffle()
    |> Enum.with_index()
    |> Enum.map(fn {em, i} -> {i, {:hidden, em}} end)
  end

  defp inc_point(players, player_id) do
    Enum.find_index(players, fn %{id: id, score: _} -> id == player_id end)
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
