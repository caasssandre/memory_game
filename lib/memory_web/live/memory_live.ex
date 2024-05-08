defmodule MemoryWeb.MemoryLive do
  use MemoryWeb, :live_view

  alias Memory.Database

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Memory.PubSub, "memory")
    end

    socket = assign(socket, board: Database.board(), players: Database.players(), player_id: nil)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="bg-gray-100">
      <div class="container mx-auto p-4">
        <h1 class="text-2xl font-bold">Memory</h1>
        <p :if={@player_id != nil}>You are player <%= @player_id %></p>
        <ul :for={%{id: id, score: score} <- @players} style="list-style: disc;" class="ml-4">
          <li>Score for player <%= id %>: <%= score %></li>
        </ul>

        <p class="text-gray-600">A simple memory game</p>

        <div class="text-2xl ml-4 flex flex-wrap">
          <p :for={{i, {status, emoji}} <- @board} class="m-3">
            <span
              :if={status == :hidden}
              phx-click="open_emoji"
              phx-value-id={i}
              class="cursor-pointer"
            >
              X
            </span>
            <span :if={status == :open || status == :guessed} class="cursor-default">
              <%= emoji %>
            </span>
          </p>
        </div>
      </div>

      <button
        :if={@player_id == nil}
        phx-click="join_game"
        class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded m-4"
      >
        Join game
      </button>

      <button
        phx-click="reset_game"
        class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded m-4"
      >
        Reset game
      </button>
    </div>
    """
  end

  def handle_event("open_emoji", %{"id" => emoji_id}, socket) do
    Database.open(emoji_id)
    Phoenix.PubSub.broadcast(Memory.PubSub, "memory", :board_updated)
    Process.send_after(self(), :check_open_emojis, 3000)

    {:noreply,
     assign(socket,
       board: Database.board(),
       players: Database.players()
     )}
  end

  def handle_event("reset_game", _params, socket) do
    Database.reset()
    Phoenix.PubSub.broadcast(Memory.PubSub, "memory", :board_updated)

    {:noreply,
     assign(socket,
       board: Database.board(),
       players: Database.players(),
       player_id: nil
     )}
  end

  def handle_event("join_game", _params, socket) do
    player_id = Database.join_game_room()
    Phoenix.PubSub.broadcast(Memory.PubSub, "memory", {:player_joined})

    {:noreply,
     assign(socket,
       board: Database.board(),
       players: Database.players(),
       player_id: player_id
     )}
  end

  def handle_info(:check_open_emojis, socket) do
    Database.check_open_emojis(socket.assigns.player_id)
    Phoenix.PubSub.broadcast(Memory.PubSub, "memory", :board_updated)

    {:noreply,
     socket
     |> assign(
       board: Database.board(),
       players: Database.players()
     )}
  end

  def handle_info(:board_updated, socket) do
    {:noreply,
     socket
     |> assign(
       board: Database.board(),
       players: Database.players()
     )}
  end

  def handle_info({:player_joined}, socket) do
    {:noreply,
     socket
     |> assign(players: Database.players())}
  end
end
