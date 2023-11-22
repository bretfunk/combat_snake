defmodule CombatSnake.Game.GameServer do
  use GenServer
  alias CombatSnake.Game.State

  # Starting the GenServer
  def start_link(_args) do
    GenServer.start_link(__MODULE__, %State{}, name: __MODULE__)
  end

  # GenServer init callback
  def init(state) do
    {:ok, state, {:continue, :start_game}}
  end

  def handle_continue(:start_game, state) do
    # Start the game logic tick
    Process.send_after(self(), :tick, 1000)
    {:noreply, state}
  end

  # Handling calls
  def handle_call({:add_player, player_id}, _from, state) do
    initial_position = {rand_position(state.board_width), rand_position(state.board_height)}
    new_state = State.add_player(state, player_id, initial_position)
    {:reply, :ok, new_state}
  end

  # Handling periodic game updates
  def handle_info(:tick, state) do
    new_state = update_game(state)
    check_collisions(new_state)
    broadcast_state(new_state)

    if state.game_duration > 0 do
      Process.send_after(self(), :tick, 1000) # Adjust timing as needed
      {:noreply, State.decrease_game_duration(new_state)}
    else
      {:noreply, State.end_game(new_state)}
    end
  end

  # Additional functions
defp update_game(state) do
  new_state = Enum.reduce(state.players, %State{state | players: %{}}, fn {player_id, player}, acc ->
    # Calculate new position based on current direction
    new_position = calculate_new_position(player["position"], player["direction"], state.board_width, state.board_height)

    # Update player's positions MapSet
    updated_positions = MapSet.put(player["positions"], new_position)

    # Update player's data
    updated_player = Map.put(player, "position", new_position)
                      |> Map.put("positions", updated_positions)
    # updated_players = Map.put(acc.players, player_id, updated_player)

    # acc
    Map.put(acc.players, player_id, updated_player)
  end)

  # Check if it's time to shrink the board
  if state.game_duration > 0 and rem(state.game_duration, 10) == 0 do
    shrink_board(new_state)
  else
    new_state
  end
end

  # defp calculate_new_position(position, direction, board_width, board_height) do
  #   case direction do
  #     "up" -> {elem(position, 0), elem(position, 1) - 1}
  #     "down" -> {elem(position, 0), elem(position, 1) + 1}
  #     "left" -> {elem(position, 0) - 1, elem(position, 1)}
  #     "right" -> {elem(position, 0) + 1, elem(position, 1)}
  #     _ -> position
  #   end

  #   # Wrap around the board

  # end

defp check_collisions(state) do
  Enum.reduce(state.players, state, fn {player_id, player}, acc ->
    other_players = Map.delete(acc.players, player_id)
    other_positions = Enum.reduce(other_players, MapSet.new(), fn {_id, p}, acc -> MapSet.union(acc, p.positions) end)

    if MapSet.member?(other_positions, player.position) do
      # Handle collision
      # handle_collision(acc, player_id, other_players)
      handle_collision(acc, player_id)
    else
      acc
    end
  end)
end

defp handle_collision(state, collided_player_id) do
  new_players = Map.update!(state.players, collided_player_id, fn player ->
    # Mark the player's name with a strikethrough
    updated_name = "<del>" <> player["name"] <> "</del>"

    # Clear the player's positions
    updated_positions = MapSet.new()

    # Update the player map
    Map.put(player, "name", updated_name)
       |> Map.put("positions", updated_positions)
  end)

  %State{state | players: new_players}
end


  defp broadcast_state(state) do
    CombatSnakeWeb.Endpoint.broadcast("game:updates", "update", %{state: state})
  end

  defp rand_position(max), do: :rand.uniform(max) - 1
end
