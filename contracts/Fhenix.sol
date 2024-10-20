// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@fhenixprotocol/contracts/FHE.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract BlackJack is ReentrancyGuard {
    struct Player {
        euint8[] hand;
        uint256 bet;
        bool hasStood;
        bool hasBusted;
    }

    struct Game {
        address[] players;
        mapping(address => Player) playerInfo;
        uint8[] dealerHand;
        uint8 currentPlayerIndex;
        bool isActive;
        euint256 pot;
    }

    mapping(uint256 => Game) public games;
    uint256 public gameCount;

    uint256 public constant MIN_BET = 0.01 ether;
    uint256 public constant MAX_PLAYERS = 7;

    event GameCreated(uint256 gameId, address creator);
    event PlayerJoined(uint256 gameId, address player);
    event GameStarted(uint256 gameId);
    event CardDealt(uint256 gameId, address player, uint8 card);
    event PlayerStood(uint256 gameId, address player);
    event PlayerBusted(uint256 gameId, address player);
    event GameEnded(uint256 gameId, address[] winners, uint256 payout);

    function createGame() external payable {
        require(msg.value >= MIN_BET, "Bet must be at least the minimum");

        gameCount++;
        Game storage newGame = games[gameCount];
        newGame.players.push(msg.sender);
        newGame.playerInfo[msg.sender] = Player({
            hand: new euint8[](0),
            bet: msg.value,
            hasStood: false,
            hasBusted: false
        });
        newGame.isActive = true;
        newGame.pot = FHE.asEuint256(msg.value);

        emit GameCreated(gameCount, msg.sender);
        emit PlayerJoined(gameCount, msg.sender);
    }

    function joinGame(uint256 gameId) external payable {
        Game storage game = games[gameId];
        require(game.isActive, "Game is not active");
        require(game.players.length < MAX_PLAYERS, "Game is full");
        require(msg.value >= MIN_BET, "Bet must be at least the minimum");
        require(msg.value == game.playerInfo[game.players[0]].bet, "Bet must match the creator's bet");

        game.players.push(msg.sender);
        game.playerInfo[msg.sender] = Player({
            hand: new euint8[](0),
            bet: msg.value,
            hasStood: false,
            hasBusted: false
        });

        uint256 gamePot = FHE.decrypt(game.pot);
        gamePot = gamePot + msg.value;
        game.pot = FHE.asEuint256(gamePot);

        emit PlayerJoined(gameId, msg.sender);

        if (game.players.length == MAX_PLAYERS) {
            startGame(gameId);
        }
    }

    function startGame(uint256 gameId) internal {
        Game storage game = games[gameId];
        require(game.players.length >= 2, "Not enough players");

        // Deal initial cards
        for (uint256 i = 0; i < game.players.length; i++) {
            dealCard(gameId, game.players[i]);
            dealCard(gameId, game.players[i]);
        }

        // Deal dealer's first card
        game.dealerHand.push(getRandomCard());

        emit GameStarted(gameId);
    }

    function hit(uint256 gameId) external {
        Game storage game = games[gameId];
        require(game.isActive, "Game is not active");
        require(msg.sender == game.players[game.currentPlayerIndex], "Not your turn");

        dealCard(gameId, msg.sender);

        if (calculateHandValueForPlayers(game.playerInfo[msg.sender].hand) > 21) {
            game.playerInfo[msg.sender].hasBusted = true;
            emit PlayerBusted(gameId, msg.sender);
            nextPlayer(gameId);
        }
    }

    function stand(uint256 gameId) external {
        Game storage game = games[gameId];
        require(game.isActive, "Game is not active");
        require(msg.sender == game.players[game.currentPlayerIndex], "Not your turn");

        game.playerInfo[msg.sender].hasStood = true;
        emit PlayerStood(gameId, msg.sender);
        nextPlayer(gameId);
    }

    function nextPlayer(uint256 gameId) internal {
        Game storage game = games[gameId];
        game.currentPlayerIndex++;

        if (game.currentPlayerIndex >= game.players.length) {
            endGame(gameId);
        } else {
            // Skip players who have already stood or busted
            while (game.currentPlayerIndex < game.players.length &&
                   (game.playerInfo[game.players[game.currentPlayerIndex]].hasStood ||
                    game.playerInfo[game.players[game.currentPlayerIndex]].hasBusted)) {
                game.currentPlayerIndex++;
            }

            if (game.currentPlayerIndex >= game.players.length) {
                endGame(gameId);
            }
        }
    }

    function endGame(uint256 gameId) internal {
        Game storage game = games[gameId];

        // Dealer hits until 17 or higher
        while (calculateHandValueForDealer(game.dealerHand) < 17) {
            game.dealerHand.push(getRandomCard());
        }

        uint8 dealerScore = calculateHandValueForDealer(game.dealerHand);
        address[] memory winners = new address[](game.players.length);
        uint256 winnerCount = 0;

        for (uint256 i = 0; i < game.players.length; i++) {
            address player = game.players[i];
            uint8 playerScore = calculateHandValueForPlayers(game.playerInfo[player].hand);

            if (!game.playerInfo[player].hasBusted &&
                (playerScore > dealerScore || dealerScore > 21 || playerScore == 21)) {
                winners[winnerCount] = player;
                winnerCount++;
            }
        }

        
        uint256 payout = FHE.decrypt(game.pot) / winnerCount;
        for (uint256 i = 0; i < winnerCount; i++) {
            payable(winners[i]).transfer(payout);
        }

        emit GameEnded(gameId, winners, payout);
        game.isActive = false;
    }

    function dealCard(uint256 gameId, address player) internal {
        uint8 card = getRandomCard();
        games[gameId].playerInfo[player].hand.push(FHE.asEuint8(card));
        emit CardDealt(gameId, player, card);
    }

    function getRandomCard() private view returns (uint8) {
        return uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % 13) + 1;
    }

    function calculateHandValueForPlayers(euint8[] memory hand) internal pure returns (uint8) {
        uint8 value = 0;
        uint8 aceCount = 0;

        for (uint256 i = 0; i < hand.length; i++) {
            uint8 card = FHE.decrypt(hand[i]);
            if (card == 1) {
                aceCount++;
                value += 11;
            } else if (card >= 10) {
                value += 10;
            } else {
                value += card;
            }
        }

        while (value > 21 && aceCount > 0) {
            value -= 10;
            aceCount--;
        }

        return value;
    }

    function calculateHandValueForDealer(uint8[] memory hand) internal pure returns (uint8) {
        uint8 value = 0;
        uint8 aceCount = 0;

        for (uint256 i = 0; i < hand.length; i++) {
            if (hand[i] == 1) {
                aceCount++;
                value += 11;
            } else if (hand[i] >= 10) {
                value += 10;
            } else {
                value += hand[i];
            }
        }

        while (value > 21 && aceCount > 0) {
            value -= 10;
            aceCount--;
        }

        return value;
    }
}
