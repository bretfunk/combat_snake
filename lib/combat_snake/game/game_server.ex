defmodule CombatSnake.Game.GameServer do
  use GenServer
  alias CombatSnake.Game.State

  # Start the GenServer with the initial state
  def start_link(_initial_state) do
    GenServer.start_link(__MODULE__, %State{}, name: __MODULE__)
  end

  # Initialize the GenServer
  def init(state) do
    IO.inspect(state, label: "init state")
    {:ok, state}
  end

  # def start_game() do
  #   :timer.send_interval(1000, :tick)
  #   {:noreply, nil}
  # end  # Public function to start the game timer

  def start_game do
    GenServer.cast(__MODULE__, :start_timer)
  end

  def end_game do
    GenServer.cast(__MODULE__, :end_game)
  end

  # Function to fetch the current state
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  # Add a new player to the game
  def add_player(player_id, name) do
    GenServer.call(__MODULE__, {:add_player, player_id, name})
  end

  # Public function to move a player
  def move_player(player_id, direction) do
    GenServer.cast(__MODULE__, {:move_player, player_id, direction})
  end

  # Handle calls to the GenServer
  def handle_call({:add_player, player_id, name}, _from, state) do
    new_position = random_position(state.board_width, state.board_height, state.players)

    new_player = %{
      id: player_id,
      name: name,
      position: new_position,
      score: 0,
      body: [new_position]
    }

    new_players = Map.put(state.players, player_id, new_player)
    new_state = %State{state | players: new_players}
    {:reply, :ok, new_state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_info(:tick, state) do
    # Decrement the game duration by 1 second
    new_game_duration = state.game_duration - 1

    # Check if the game duration has reached zero
    if new_game_duration < 0 do
      # Handle the end of the game
      GenServer.cast(__MODULE__, :end_game)
      {:noreply, state}
    else
      # Update the game state with the new game duration
      new_state = %State{state | game_duration: new_game_duration}
      # Broadcast the updated state
      broadcast_state(new_state)
      {:noreply, new_state}
    end
  end

  # Handling the :end_game message
  def handle_cast(:end_game, state) do
    # Cancel the ongoing timer if it exists
    if is_reference(state.timer_ref) do
      :erlang.cancel_timer(state.timer_ref)
    end

    # Optionally reset the game state or take other necessary actions

    # Stop the GenServer if needed. Otherwise, return the modified state.
    {:stop, :normal, state}
  end

  def handle_cast(:start_timer, state) do
    # Start the interval timer and save the reference
    timer_ref = :timer.send_interval(1000, :tick)
    {:noreply, Map.put(state, :timer_ref, timer_ref)}
  end

  # Handling the :move_player message
  def handle_cast({:move_player, player_id, direction}, state) do
    new_state = update_player_position(state, player_id, direction)
    broadcast_state(new_state)
    {:noreply, new_state}
  end

  # Update the position of a single player
  defp update_player_position(state, player_id, direction) do
    new_players =
      Map.update!(state.players, player_id, fn player ->
        new_head_position =
          next_position(Enum.at(player.body, 0), direction, state.board_width, state.board_height)

        new_body = [new_head_position | Enum.take(player.body, state.snake_size - 1)]
        Map.put(player, :body, new_body)
      end)

    new_state = %State{state | players: new_players}
    check_collisions(new_state)
    new_state
  end

  # # Update the positions of all players
  # defp update_players(state) do
  #   Enum.reduce(state.players, %State{state | players: %{}}, fn {player_id, player}, acc ->
  #     # Calculate new head position based on current direction
  #     new_head_position =
  #       next_position(player.body |> hd, player.direction, state.board_width, state.board_height)

  #     # Update body positions: new head position followed by the rest excluding the last segment
  #     new_body = [new_head_position | Enum.take(player.body, state.snake_size - 1)]

  #     # Update player's data in the state
  #     updated_player = Map.put(player, :body, new_body)
  #     Map.put(acc.players, player_id, updated_player)
  #     # bret removed this
  #     # updated_players = Map.put(acc.players, player_id, updated_player)

  #     # acc
  #   end)
  # end

  # Calculate the next position based on direction and board size
  defp next_position({x, y}, direction, width, height) do
    case direction do
      "up" -> {x, rem(y - 1 + height, height)}
      "down" -> {x, rem(y + 1, height)}
      "left" -> {rem(x - 1 + width, width), y}
      "right" -> {rem(x + 1, width), y}
      _ -> {x, y}
    end
  end

  # Check for collisions between players
  defp check_collisions(state) do
    Enum.reduce(state.players, state, fn {player_id, player}, acc ->
      other_players = Map.delete(acc.players, player_id)

      if Enum.any?(other_players, fn {_id, op} -> Enum.member?(op.body, player.position) end) do
        # Handle collision
        handle_collision(acc, player_id)
      else
        acc
      end
    end)
  end

  # Handle collision consequences
  defp handle_collision(state, collided_player_id) do
    # Remove collided player and increment score of colliding player
    {collided_player, remaining_players} = Map.pop(state.players, collided_player_id)

    new_players =
      Enum.reduce(remaining_players, remaining_players, fn {id, player}, acc ->
        if Enum.member?(player.body, collided_player.position) do
          Map.update!(acc, id, fn p -> Map.update!(p, :score, &(&1 + 1)) end)
        else
          acc
        end
      end)

    %State{state | players: new_players}
  end

  # Broadcast the current game state
  defp broadcast_state(state) do
    CombatSnakeWeb.Endpoint.broadcast("game:updates", "update", %{state: state})
  end

  # Generate a random starting position that is far from other players
  defp random_position(width, height, players) do
    Enum.reduce_while(1..100, nil, fn _, _ ->
      pos = {rand_position(width), rand_position(height)}

      if Enum.all?(players, fn {_id, p} -> distance(p.position, pos) > 5 end) do
        {:halt, pos}
      else
        {:cont, nil}
      end
    end) || {0, 0}
  end

  defp rand_position(max), do: :rand.uniform(max - 1)
  defp distance({x1, y1}, {x2, y2}), do: :math.sqrt(:math.pow(x2 - x1, 2) + :math.pow(y2 - y1, 2))
end
