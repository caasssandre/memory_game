defmodule MemoryWeb.MemoryLive do
  use MemoryWeb, :live_view

  alias Memory.Database

  def mount(_params, _session, socket) do
    socket = assign(socket, board: Database.board(), players: Database.players())

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Memory.PubSub, "memory")
    else
      Database.join_game_room(socket.id)
    end

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="bg-gray-100">
      <div class="container mx-auto p-4">
        <h1 class="text-2xl font-bold">Memory</h1>

        <ul :for={{player, %{id: _, score: score}} <- @players} style="list-style: disc;" class="ml-4">
          <li>Score: <%= player %>: <%= score %></li>
        </ul>

        <p class="text-gray-600">A simple memory game</p>

        <ul :for={{i, {status, emoji}} <- @board} style="list-style: disc;" class="ml-4">
          <li :if={status == :hidden} phx-click="open_emoji" phx-value-id={i}>X</li>
          <li :if={status == :open || status == :guessed}><%= emoji %></li>
        </ul>
      </div>

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
    {:noreply, assign(socket, board: Database.board())}
  end

  def handle_event("reset_game", _params, socket) do
    Database.reset()
    {:noreply, assign(socket, board: Database.board())}
  end
end
