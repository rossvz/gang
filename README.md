# Gang

Gang is a cooperative, multiplayer poker-based card game, shamelessly adapted from the card game of the same name. [Check it out](https://store.thamesandkosmos.com/products/the-gang?srsltid=AfmBOopgB7BiNveSWKGek61XG8bQe85DvsjydYQoTg_AmKawiEdh07al)

## Rules

See [rules](./rules.md)

## Implementation

This app is a phoenix live-view app.

The initial version will use no database or persistence, games are just stored in GenServer process state.

We will leverage LiveView and real-time phoenix primitives to allow the multiplayers capabilities and sync game state to all connected clients.

## Pages

- Home: (`/`) The home screen for the app will simply list a `New Game` and `Join Game` actions, along with a link to the rules.
- Game: (`/games/AR7Q)`). Each game has a unique join code that will let clients connect to that game state (if there are available seats.)
- Rules: `/rules/` Contains a written summary of the rules and how to play.

## UI

A player will see their own cards but none of the cards of other players. The player can see the community cards (the flop, turn, river), as well as the "rank chips" on the screen.
Clicking a rank chip will either claim it to the user's hand, or return it to the middle.

Players should be able to see the other players in the session, change their username, and see an active indicator if the other players are actively connected to the game session.

## Game

When a user creates a new game, a new supervised Game process is started.
The game will generate a 4 character "share code".
the game will track the current players, round information, rank chip information, and automatically progress through the stages of the game, and calculate the scoring and ultimately the win or loss condition. See state snippet below.

The Game will wait for players to join until the "host" officially starts the game.
We move into the `preflop` and the Game will deal cards to each player. This will notify the LiveView process that each player is subscribed to and show each player their hand.

Players will see the unclaimed rank chips and interact with them, moving them around to claim them. Players can see the which player has claimed which chip.

When all chips are claimed, the genserver will alert players the round is ending, wait 3 seconds and then deal the `flop` and the rounds will proceed.

Eg 

```elixir
@type round :: :waiting, :preflop | :flop | :turn | :river | :round_end | :game_end



%Game.State{
  game_start: %DateTime{},
  last_active: %DateTime{}, # incremented for any player action. Used to cleanup or shutdown older games.
  code: "AB3G",
  players: [
    %Player{pid: PID<...>, cards: [...], rank_chips: [%Rank{}] }
  ],
  round: :preflop,
  vaults: 0,
  alarms: 0,
  community_cards: [%Card{rank: 2, suite: :spades}, ...],
  unclaimed_rank_chips: [%{
    preflop: [%Rank{color: :white, rank: 2}, ...],
    flop: [%Rank{color: :yellow, rank: 2}],
    # etc...
  }],
  deck: [%Card{}] # starts with full 52 card deck (no jokers)
}

```

Completed or abandoned games (where all players have left) will be kept around for a while, and then eventually the process will be stopped.


# Persistance

Games will be (eventually) serialized to DB on a regularly interval or during app restarts.

When the app boots it should find any in-progress games and warm the supervised processes with those games to allow a seamless rejoining experience.

When players create or join a game we'll generate an ID (UUID) and the client will store than in localStorage. (if a user refreshes or disconnects, they should return to the same state they had before)