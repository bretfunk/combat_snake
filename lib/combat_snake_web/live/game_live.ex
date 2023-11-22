defmodule CombatSnakeWeb.GameLive do
  use Phoenix.LiveView
  alias CombatSnake.Game.GameServer

  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Phoenix.PubSub.subscribe(CombatSnakeWeb.Endpoint, "game:updates")
      CombatSnakeWeb.Endpoint.subscribe("game:updates")
    end

    game_state = GameServer.get_state()

    {:ok, assign(socket, %{state: game_state})}
  end

  def handle_info(%{event: "update", payload: %{state: new_state}}, socket) do
    {:noreply, assign(socket, :state, new_state)}
  end

  def handle_info(:tick, socket) do
    IO.puts("tick")
    {:noreply, socket}
  end

  def handle_event("add_player", %{"name" => name}, socket) do
    GameServer.add_player(name, name)
    {:noreply, socket}
  end

  def handle_event("start_game", _, socket) do
    GameServer.start_game()
    |> IO.inspect(label: "start game")

    {:noreply, socket}
  end

  def handle_event("move", %{"direction" => direction}, socket) do
    # Assuming `player_id` is available in your socket assigns or session
    player_id = socket.assigns.current_player_id
    GameServer.move_player(player_id, direction)
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center p-4">
      <div class="flex justify-between w-full mb-4">
        <div id="scoreboard">
          <%= for {_player_id, player} <- assigns.state.players do %>
            <p><%= player.name %>: <%= player.score %></p>
          <% end %>
        </div>
        <div id="game-timer">
          Time left: <%= assigns.state.game_duration %>
        </div>
      </div>

      <div class={grid(assigns)}>
        <%= for y <- 0..assigns.state.board_height - 1 do %>
          <%= for x <- 0..assigns.state.board_width - 1 do %>
            <%= render_cell(assigns, x, y) %>
          <% end %>
        <% end %>
      </div>

      <form phx-submit="add_player" class="my-4">
        <input
          type="text"
          name="name"
          placeholder="Enter player name"
          class="mr-2 p-1 border rounded"
        />
        <button type="submit" class="p-1 border rounded bg-blue-500 text-white">Add Player</button>
      </form>

      <button phx-click="start_game" class="p-1 border rounded bg-green-500 text-white">
        Start Game
      </button>
    </div>
    """
  end

  defp grid(assigns) do
    # Calculate grid classes
    grid_cols_class = "grid-cols-#{assigns.state.board_width}"
    grid_rows_class = "grid-rows-#{assigns.state.board_height}"

    "grid " <> grid_cols_class <> grid_rows_class <> "gap-1"
  end

  defp render_cell(assigns, x, y) do
    ~H"""
    <div class="w-6 h-6 border border-gray-200 #{player_color_at(assigns.state.players, {x, y})}">
    </div>
    """
  end

  defp player_color_at(players, position) do
    players
    |> Enum.find_value("bg-transparent", fn {_id, player} ->
      if Enum.member?(player.body, position), do: random_color_class(), else: "bg-black-500"
    end)
  end

  defp random_color_class() do
    Enum.random([
      "bg-red-500",
      "bg-green-500",
      "bg-blue-500",
      "bg-yellow-500",
      "bg-purple-500",
      "bg-orange-500"
    ])
  end
end
