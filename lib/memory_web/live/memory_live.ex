defmodule MemoryWeb.MemoryLive do
  use MemoryWeb, :live_view

  alias Memory.Database

  def mount(%{"player_id" => player_id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Memory.PubSub, "memory")
    end

    players = Database.players()

    socket =
      assign(socket,
        board: Database.board(),
        players: players,
        player_id: String.to_integer(player_id),
        winner: nil,
        current_player: Database.current_player(),
        turn_in_progress: false
      )

    if Enum.any?(players, fn p -> p.id == player_id end) do
      {:ok, socket}
    else
      Process.send(self(), :game_reset, [:noconnect])
      {:ok, socket}
    end
  end

  def mount(_params, _session, socket) do
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
          :if={@player_id != nil}
          player_id={@player_id}
          players={@players}
          current_player={@current_player}
          winner={@winner}
          turn_in_progress={@turn_in_progress}
        />
      </div>
      <.board
        :if={length(@players) == 2 && @winner == nil && @player_id != nil}
        board={@board}
        player_id={@player_id}
        current_player={@current_player}
        turn_in_progress={@turn_in_progress}
      />
      <.actions_box player_id={@player_id} , players={@players} />
    </div>
    """
  end

  def board(assigns) do
    ~H"""
    <div class="grid grid-cols-4 gap-1">
      <p :for={{i, {status, emoji}} <- @board} class="m-3">
        <.cell
          id={i}
          status={status}
          emoji={emoji}
          current_player={@current_player}
          local_player_id={@player_id}
          turn_in_progress={@turn_in_progress}
        />
      </p>
    </div>
    """
  end

  def cell(
        %{
          status: :hidden,
          current_player: current_player,
          local_player_id: local_player_id,
          turn_in_progress: turn_in_progress
        } =
          assigns
      )
      when current_player == local_player_id and not turn_in_progress do
    ~H"""
    <span
      phx-click="show_emoji"
      phx-value-id={@id}
      class="cursor-pointer text-3xl flex justify-center items-center"
    >
      X
    </span>
    """
  end

  def cell(%{status: :hidden} = assigns) do
    ~H"""
    <span class="text-3xl flex justify-center items-center">X</span>
    """
  end

  def cell(assigns) do
    ~H"""
    <span class="text-3xl flex justify-center items-center"><%= @emoji %></span>
    """
  end

  def game_state(assigns) do
    ~H"""
    <p>You are player <%= @player_id + 1 %></p>

    <.message
      :if={length(@players) == 2}
      winner={@winner}
      turn_in_progress={@turn_in_progress}
      current_player={@current_player}
      local_player_id={@player_id}
    />
    <ul :for={%{id: id, score: score} <- @players} style="list-style: disc;" class="ml-4">
      <li>Score for player <%= id %>: <%= score %></li>
    </ul>
    """
  end

  def message(assigns) when not is_nil(assigns.winner) do
    ~H"""
    <p class="text-green-500">The game is over. Player <%= @winner %> won!</p>
    """
  end

  def message(%{turn_in_progress: true} = assigns) do
    ~H"""
    <p class="text-blue-500">Memorize the emojis before they disappear!</p>
    """
  end

  def message(%{current_player: current_player, local_player_id: local_player_id} = assigns)
      when current_player == local_player_id do
    ~H"""
    <p class="text-green-500">It's your turn</p>
    """
  end

  def message(assigns) do
    ~H"""
    <p class="text-red-500">Waiting for other player to play</p>
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
      :if={length(@players) > 0}
      phx-click="reset_game"
      class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded m-4"
    >
      Reset game
    </button>
    """
  end

  def handle_event("show_emoji", %{"id" => emoji_id}, socket) do
    latest_board = Database.show_emoji(String.to_integer(emoji_id))

    if Enum.count(latest_board, fn {_id, {status, _}} -> status == :visible end) == 2 do
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

    {:noreply, socket}
  end

  def handle_event("join_game", _params, socket) do
    player_id = Database.join_game_room()
    Phoenix.PubSub.broadcast(Memory.PubSub, "memory", :player_joined)

    socket =
      socket
      |> assign(
        board: Database.board(),
        players: Database.players(),
        player_id: player_id
      )

    {:noreply, push_patch(socket, to: "/memory/#{player_id}")}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
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
    socket =
      socket
      |> assign(
        board: Database.board(),
        players: Database.players(),
        current_player: Database.current_player(),
        player_id: nil,
        winner: nil
      )

    {:noreply, push_patch(socket, to: "/memory")}
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

  defp reload_board() do
    case Database.check_open_emojis() do
      :good_guess ->
        Phoenix.PubSub.broadcast(Memory.PubSub, "memory", :game_updated)

      :game_over ->
        Phoenix.PubSub.broadcast(Memory.PubSub, "memory", :game_over)

      :no_guess ->
        Process.send_after(self(), :game_updated_delayed, 3000)
    end
  end
end
