defmodule Memory.Database do
  use GenServer
  @emojis ["😀", "😂", "😅", "😍", "😎", "😏", "😡", "🥳", "😭", "🤔", "🤩", "🤷"]

  def start_link(_opts), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  def board(pid \\ __MODULE__), do: GenServer.call(pid, :board)
  def players(pid \\ __MODULE__), do: GenServer.call(pid, :players)
  def current_player(pid \\ __MODULE__), do: GenServer.call(pid, :current_player)
  def join_game_room(pid \\ __MODULE__), do: GenServer.call(pid, :join_game_room)
  def show_emoji(pid \\ __MODULE__, emoji_id), do: GenServer.call(pid, {:show_emoji, emoji_id})
  def check_open_emojis(pid \\ __MODULE__), do: GenServer.call(pid, :check_open_emojis)
  def reset(pid \\ __MODULE__), do: GenServer.call(pid, :reset)

  def init(_opts) do
    {:ok, %{board: generate_game_board(), players: [], current_player: 0}}
  end

  def handle_call(:board, _from, state), do: {:reply, state.board, state}
  def handle_call(:players, _from, state), do: {:reply, Enum.reverse(state.players), state}
  def handle_call(:current_player, _from, state), do: {:reply, state.current_player, state}

  def handle_call(:join_game_room, _from, %{players: []} = state) do
    state = %{state | players: [%{id: 1, score: 0}]}

    {:reply, 0, state}
  end

  def handle_call(:join_game_room, _from, %{players: [player_one | []]} = state) do
    state = %{state | players: [%{id: 2, score: 0}, player_one]}

    {:reply, 1, state}
  end

  def handle_call(:join_game_room, _from, state) do
    {:reply, :error, state}
  end

  def handle_call({:show_emoji, emoji_id}, _from, %{board: board} = state) do
    board = List.update_at(board, emoji_id, &change_emoji_status(&1, :visible))

    state = %{state | board: board}
    {:reply, board, state}
  end

  def handle_call(:check_open_emojis, _from, %{board: board} = state) do
    {outcome, players, board, current_player} =
      Enum.filter(board, fn {_id, {status, _}} -> status == :visible end)
      |> analyse_emoji_pair(state)

    state =
      state
      |> Map.update!(:players, fn _ -> players end)
      |> Map.update!(:board, fn _ -> board end)
      |> Map.update!(:current_player, fn _ -> current_player end)

    {:reply, outcome, state}
  end

  def handle_call(:reset, _from, state) do
    state =
      state
      |> Map.update!(:players, fn _ -> [] end)
      |> Map.update!(:board, fn _ -> generate_game_board() end)
      |> Map.update!(:current_player, fn _ -> 0 end)

    {:reply, :ok, state}
  end

  defp analyse_emoji_pair([{id1, {_, emoji}}, {id2, {_, emoji}}], state) do
    %{board: board, players: players, current_player: current_player} = state

    board =
      board
      |> List.update_at(id1, &change_emoji_status(&1, :guessed))
      |> List.update_at(id2, &change_emoji_status(&1, :guessed))

    players = inc_point(players, current_player + 1)

    outcome =
      if Enum.all?(board, fn {_id, {status, _}} -> status == :guessed end) do
        :game_over
      else
        :good_guess
      end

    {outcome, players, board, current_player}
  end

  defp analyse_emoji_pair([{id1, {_, _}}, {id2, {_, _}}], state) do
    %{board: board, players: players, current_player: current_player} = state

    board =
      board
      |> List.update_at(id1, &change_emoji_status(&1, :hidden))
      |> List.update_at(id2, &change_emoji_status(&1, :hidden))

    {:no_guess, players, board, (current_player + 1) |> rem(2)}
  end

  defp generate_game_board do
    (@emojis ++ @emojis)
    |> Enum.shuffle()
    |> Enum.with_index()
    |> Enum.map(fn {em, i} -> {i, {:hidden, em}} end)
  end

  defp inc_point(players, player_id) do
    Enum.find_index(players, fn %{id: id, score: _} -> id == player_id end)
    |> case do
      nil ->
        :error

      index ->
        List.update_at(players, index, fn %{id: id, score: score} ->
          %{id: id, score: score + 1}
        end)
    end
  end

  defp change_emoji_status(emoji, new_status) do
    {id, {_status, em}} = emoji
    {id, {new_status, em}}
  end
end
