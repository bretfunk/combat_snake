defmodule CombatSnake.Game.State do
  defstruct players: %{}, board_width: 20, board_height: 20, game_over: false, game_duration: 60, inital_player_size: 4

  # Function to add a new player to the game state
  def add_player(state, player_id, initial_position) do
    new_players = Map.put(state.players, player_id, initial_position)
    %__MODULE__{state | players: new_players}
  end

  # Function to update a player's position
  def update_player_position(state, player_id, new_position) do
    new_players = Map.update!(state.players, player_id, fn _ -> new_position end)
    %__MODULE__{state | players: new_players}
  end

  # Function to check if the game is over (stubbed for now)
  def check_game_over(state) do
    # Add logic to determine if the game is over
    %__MODULE__{state | game_over: false}
  end

  # Additional functions for game state logic can be added here
end
