defmodule MemoryWeb.MemoryLive do
  use MemoryWeb, :live_view

  alias Memory.Database

  def mount(_params, session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Memory.PubSub, "memory")
    end

    socket =
      assign(socket,
        board: Database.board(),
        players: Database.players(),
        player_id: nil,
        winner: nil,
        current_player: Database.current_player(),
        turn_in_progress: false
      )

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="bg-gray-100">
      <div class="container mx-auto p-4">
        <h1 class="text-2xl font-bold">Memory</h1>
        <.game_state
          player_id={@player_id}
          players={@players}
          current_player={@current_player}
          winner={@winner}
          turn_in_progress={@turn_in_progress}
        />

        <div class="grid grid-cols-4 gap-1">
          <p :for={{i, {status, emoji}} <- @board} class="m-3">
            <span
              :if={status == :hidden && @current_player + 1 == @player_id && !@turn_in_progress}
              phx-click="open_emoji"
              phx-value-id={i}
              class="cursor-pointer text-3xl flex justify-center items-center"
            >
              X
            </span>
            <span
              :if={status == :hidden && (@current_player + 1 != @player_id || @turn_in_progress)}
              class="text-3xl flex justify-center items-center"
            >
              X
            </span>
            <span
              :if={status == :open || status == :guessed}
              class="cursor-default text-3xl flex justify-center items-center"
            >
              <%= emoji %>
            </span>
          </p>
        </div>
      </div>
      <.actions_box player_id={@player_id} , players={@players} />
    </div>
    """
  end

  def game_state(assigns) do
    ~H"""
    <p :if={@winner != nil} class="text-green-500">Player <%= @winner %> won!</p>
    <p :if={@player_id != nil}>You are player <%= @player_id %></p>
    <p :if={@turn_in_progress} class="text-blue-500">Memorize the emojis before they disappear!</p>
    <p :if={@current_player + 1 == @player_id && !@turn_in_progress} class="text-green-500">
      It's your turn
    </p>
    <p
      :if={@current_player + 1 != @player_id && length(@players) == 2 && !@turn_in_progress}
      class="text-red-500"
    >
      Waiting for other player to play
    </p>
    <p :if={@player_id != nil && length(@players) == 1 && @winner == nil} class="text-red-500">
      Waiting for other player to join
    </p>
    <ul :for={%{id: id, score: score} <- @players} style="list-style: disc;" class="ml-4">
      <li>Score for player <%= id %>: <%= score %></li>
    </ul>
    """
  end

  def actions_box(assigns) do
    ~H"""
    <button
      :if={@player_id == nil && length(@players) < 2}
      phx-click="join_game"
      class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded m-4"
    >
      Join game
    </button>

    <p :if={length(@players) == 2 && @player_id == nil}>
      There are already 2 players in the game. You cannot join.
    </p>

    <button
      phx-click="reset_game"
      class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded m-4"
    >
      Reset game
    </button>
    """
  end

  def handle_event("open_emoji", %{"id" => emoji_id}, socket) do
    Database.open(emoji_id)
    latest_board = Database.board()

    if latest_board
       |> Enum.filter(fn {_id, {status, _}} -> status == :open end)
       |> length() == 2 do
      Phoenix.PubSub.broadcast(Memory.PubSub, "memory", {:turn_in_progress, latest_board})
      reload_board()
    else
      Phoenix.PubSub.broadcast(Memory.PubSub, "memory", :game_updated)
    end

    {:noreply, socket}
  end

  def handle_event("reset_game", _params, socket) do
    Database.reset()
    Phoenix.PubSub.broadcast(Memory.PubSub, "memory", :game_reset)

    {:noreply,
     assign(socket,
       board: Database.board(),
       players: Database.players(),
       player_id: nil,
       current_player: Database.current_player()
     )}
  end

  def handle_event("join_game", _params, socket) do
    player_id = Database.join_game_room()
    Phoenix.PubSub.broadcast(Memory.PubSub, "memory", :player_joined)

    {:noreply,
     assign(socket,
       board: Database.board(),
       players: Database.players(),
       player_id: player_id
     )}
  end

  def reload_board() do
    case Database.check_open_emojis() do
      :good_guess ->
        Phoenix.PubSub.broadcast(Memory.PubSub, "memory", :game_updated)

      :game_over ->
        Phoenix.PubSub.broadcast(Memory.PubSub, "memory", :game_over)

      :no_guess ->
        Process.send_after(self(), :game_updated_delayed, 3000)
    end
  end

  def handle_info(:game_updated_delayed, socket) do
    Phoenix.PubSub.broadcast(Memory.PubSub, "memory", :game_updated)
    {:noreply, socket}
  end

  def handle_info(:game_updated, socket) do
    {:noreply,
     socket
     |> assign(
       board: Database.board(),
       players: Database.players(),
       current_player: Database.current_player(),
       turn_in_progress: false
     )}
  end

  def handle_info({:turn_in_progress, board}, socket) do
    {:noreply,
     socket
     |> assign(
       board: board,
       players: Database.players(),
       current_player: Database.current_player(),
       turn_in_progress: true
     )}
  end

  def handle_info(:player_joined, socket) do
    {:noreply,
     socket
     |> assign(players: Database.players())}
  end

  def handle_info(:game_reset, socket) do
    {:noreply,
     socket
     |> assign(
       board: Database.board(),
       players: Database.players(),
       current_player: Database.current_player(),
       player_id: nil
     )}
  end

  def handle_info(:game_over, socket) do
    {:noreply,
     socket
     |> assign(
       board: Database.board(),
       players: Database.players(),
       winner: Database.current_player() + 1
     )}
  end
end
