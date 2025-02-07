/**
* Name: Assignment3task1
* Based on the internal empty template. 
* Author: Dearcfy
* Tags: 
*/


model NQueens

global {
	int numberOfQueens <- 20 min: 4 max: 20;
	init {
		create Queen number: numberOfQueens;
		loop counter from: 0 to: numberOfQueens - 1 {
			Queen queen <- Queen[counter];
			Queen previousQueen <- nil;
			if (counter - 1 >= 0) {
				previousQueen <- Queen[counter - 1];
				previousQueen.nextQueen <- queen;
			}
			queen.queenIndex <- counter;
			queen.previousQueen <- previousQueen;
		}
		Queen[0].active <- true;
	}
}

species Queen skills: [fipa] {
	Queen previousQueen <- nil;
	Queen nextQueen <- nil;
	bool active <- false;
	int queenIndex <- 0;
	list<ChessBoard> possibleLocations <- [];
	list<ChessBoard> otherQueensLocations <- [];
	bool hasFoundLocations <- false;
	ChessBoard position <- nil;
		
	aspect base {
		if (position != nil) {
			location <- position.location;
			float size <- 30 / numberOfQueens;
			draw circle(size) color: rgb("green");
		}
	}	
	
	reflex getRightLocations when:active {
		// The current suitable positions have not been obtained.
		if (!hasFoundLocations) {
			possibleLocations <- getPossibleLocations();
			hasFoundLocations <- true;
		}
		if (empty(possibleLocations)) {
			do removeMemory;
			active <- false;
			do informPreviousQueen;
			return;
		}
		
//		do putCurrQueenAt(first(possibleLocations));
		do putCurrQueenAt(possibleLocations[rnd(0, length(possibleLocations) - 1)]);
		do informNextQueen;
	}
	
	action putCurrQueenAt(ChessBoard pos) {
		position <- pos;
		add item: position to: otherQueensLocations at: queenIndex;
		active <- false;
	}
	
	bool positionIsValid(ChessBoard pos) {
		if (empty(otherQueensLocations)) {
			return true;
		}
		loop prevRow from: 0 to: queenIndex - 1 {
			ChessBoard prevLocation <- otherQueensLocations[prevRow];
			if (prevLocation.grid_y = pos.grid_y or abs(prevLocation.grid_y - pos.grid_y) = abs(prevLocation.grid_x - pos.grid_x)) {
				return false;
			}
		}
		return true;
	}
	
	action getPossibleLocations {
		int startY <- 0;
    	if (previousQueen != nil) {
      	 	startY <- previousQueen.position.grid_y;
    	}
		
		list<int> potentialY <- [];
		
		loop i from: 0 to: numberOfQueens - 1 {
//			int y <- (startY + i) mod numberOfQueens;
			int y <- i;
			ChessBoard currPosition <- ChessBoard[queenIndex, y];
			bool isValid <- positionIsValid(currPosition);
			if (isValid) {
				potentialY <- potentialY + [y];
				// The commented code below does not work. I have not figured out why. I think it should be OK to access it directly.
//				possibleLocations <- possibleLocations + [currPosition];
			}
		}
		
		possibleLocations <- potentialY accumulate (ChessBoard[queenIndex, each]);
	}
	
	action removeMemory {
		possibleLocations <- [];
		otherQueensLocations <- [];
		hasFoundLocations <- false;
		position <- nil;
	}
	
	action informPreviousQueen {
		if (previousQueen = nil) {
			write "This problem is unsolvable.";
		} else {
			do start_conversation to: [previousQueen] protocol: "fipa-propose" performative: "inform" contents: ["backtrack"];
		}
	}
	
	action informNextQueen {
		if (nextQueen = nil) {
			write "Task has been finished.";
		} else {
			do start_conversation to: [nextQueen] protocol: "fipa-propose" performative: "inform" contents: ["activate", otherQueensLocations];
		}
	}
	
	reflex receiveInformation when: !active and !empty(informs) {
		loop msg over: informs {
			string act <- msg.contents[0];
			if (act = "activate") {
				otherQueensLocations <- msg.contents[1];
				active <- true;
			} else if (act = "backtrack") {
				write("[" + queenIndex + "] Received backtrack signal");
//				remove from:possibleLocations index:0;
				remove item:position from:possibleLocations;
				active <- true;
			} else {
			}
		}
	}
}

grid ChessBoard width: numberOfQueens height: numberOfQueens neighbors: 8 { 
	init{
		if (even(grid_x) and even(grid_y) or !even(grid_x) and !even(grid_y)){
			color <- #black;
		} else {
			color <- #white;
		}
	}
}

experiment NQueensProblem type: gui {
	output {
		display ChessBoard {
			grid ChessBoard border: #black;
			species Queen aspect: base;
		}
	}
}

