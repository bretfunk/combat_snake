defmodule CombatSnakeWeb.GameLive do
  use Phoenix.LiveView

  # remove this shit
  alias CombatSnake.Game.State

  def mount(_params, _session, socket) do
 # if connected?(socket), do: Phoenix.PubSub.subscribe(CombatSnakeWeb.Endpoint, "game:updates")
  
 if connected?(socket), do: CombatSnakeWeb.Endpoint.subscribe("game:updates")
    send(self(), :tick)

    {:ok, assign(socket, :state, Map.from_struct(%State{}))}
  end

  def handle_event("move", %{"player_id" => player_id, "direction" => direction}, socket) do
    new_state = move_player(socket.assigns.state, player_id, direction)
    {:noreply, assign(socket, :state, new_state)}
  end

def handle_event("join_game", %{"player_id" => player_id}, socket) do
  CombatSnake.Game.GameServer.add_player(player_id)
  {:noreply, socket}
end

  # gonna need to move faster tbh
  def handle_info(:tick, socket) do
    new_state = update_game(socket.assigns.state)

    if new_state.game_over do
      {:noreply, socket}
    else
      # Adjust timing as needed
      Process.send_after(self(), :tick, 1000)
      {:noreply, assign(socket, :state, new_state)}
    end
  end

  def render(assigns) do
    ~H"""
    <div id="combat-snake-game" class="flex flex-col items-center justify-center p-4">
      <h1 class="text-2xl font-bold mb-4">🐍 CombatSnake 🐍</h1>

      <div class="grid grid-cols-#{@board_width} gap-1">
        <%= for y <- 0..@state.board_height do %>
          <div class="flex flex-row">
            <%= for x <- 0..@state.board_width do %>
              <%= render_cell(@state, x, y) %>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # this needs to be in the genserver
  defp move_player(state, player_id, direction) do
    players = state.players
    player = players[player_id]

    new_position =
      case direction do
        "up" -> {player.position_x, player.position_y - 1}
        "down" -> {player.position_x, player.position_y + 1}
        "left" -> {player.position_x - 1, player.position_y}
        "right" -> {player.position_x + 1, player.position_y}
        _ -> {player.position_x, player.position_y}
      end

    new_player = Map.put(player, :position_x, elem(new_position, 0))
    new_player = Map.put(new_player, :position_y, elem(new_position, 1))

    new_players = Map.put(players, player_id, new_player)

    %{state | players: new_players}
  end

  #  this needs to be in the gen server
  defp update_game(state) do
    new_players =
      Enum.reduce(state.players, %{}, fn {player_id, player}, acc ->
        # Here we assume that each player has a direction
        new_position =
          case player.direction do
            "up" -> {player.position_x, player.position_y - 1}
            "down" -> {player.position_x, player.position_y + 1}
            "left" -> {player.position_x - 1, player.position_y}
            "right" -> {player.position_x + 1, player.position_y}
            _ -> {player.position_x, player.position_y}
          end

        new_player = Map.put(player, :position_x, elem(new_position, 0))
        new_player = Map.put(new_player, :position_y, elem(new_position, 1))

        Map.put(acc, player_id, new_player)
      end)

    # Check for collisions and other game logic here
    # ...

    %{state | players: new_players}
  end

  defp render_cell(assigns, x, y) do
    players = assigns.players

    cond do
      is_snake_segment?(x, y, players) ->
        ~H"<div class=\"w-6 h-6 bg-green-500 border border-gray-200\"></div>"

      true ->
        ~H"<div class=\"w-6 h-6 border border-gray-200\"></div>"
    end
  end

  defp is_snake_segment?(x, y, players) do
    Enum.any?(players, fn {_id, player} ->
      Enum.any?(player.segments, fn {seg_x, seg_y} -> seg_x == x and seg_y == y end)
    end)
  end
end
