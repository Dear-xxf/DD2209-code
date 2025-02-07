/**
* Name: Auction
* Based on the internal empty template. 
* Author: Dearcfy
* Tags: 
*/


model Auction

global {
	int numberOfBidders <- 5;
	int numberOfAuctioneers <- 3;
	init {
		create Bidder number: numberOfBidders;
		create Auctioneer number: numberOfAuctioneers;
		
		Auctioneer[0].acutionObject <- "clothes";
		Auctioneer[1].acutionObject <- "cds";
		Auctioneer[2].acutionObject <- "shoes";
		
		Bidder[0].interests <- ["clothes"];
		Bidder[1].interests <- ["cds"];
		Bidder[2].interests <- ["shoes"];
		Bidder[3].interests <- ["clothes", "cds"];
		Bidder[4].interests <- ["cds", "shoes"];
	}
}

species Bidder skills: [fipa] {
	aspect base {
		draw square(5) color: rgb("red");
	}
	int budget;
	list<string> interests <- [];
	int numberOfAuctionParticipated;
	init {
		budget <- rnd(1000, 2000);
		numberOfAuctionParticipated <- 0;
	}
	
	reflex receiveMessage when: !empty(cfps) {
		loop cfp over: cfps {
			// Auction information is transmitted through key-value pairs.
			list msg <- cfp.contents;
			pair msgPair <- msg[0];
			string msgType <- msgPair.key;
			
			switch msgType { 
   				match "Notify" {
   					// Notify of new auction starts.
   					// If bidder want to participate, it don't need to reply, the auctioneer will be added to the list by default.
   					Auctioneer acutioneer <- cfp.sender;
   					if (!shouldParticipateAuction(msgPair.value)) {
   						pair<string, string> intermediatePair <- "NoParticipate" :: "Reject";
   						do refuse message:cfp contents: [intermediatePair];
   						write "(" + name + "): " + "I quit the auction of " + acutioneer.name;
   					} else {
   						write "(" + name + "): " + "I want play the auction of " + acutioneer.name;
   						numberOfAuctionParticipated <- numberOfAuctionParticipated + 1;
   					}
				}
				match "Price" {
					int currentPrice <- int(msgPair.value);
					bool shouldAccept <- shouldAcceptCurrentPrice(currentPrice);
					if (!shouldAccept) {
						pair<string, string> intermediatePair <- "Answer" :: "Reject";
						do refuse message:cfp contents: [intermediatePair];
						write "(" + name + "): " + "Reject this offer of " + cfp.sender + "My budget is " + budget;
					} else {
						pair<string, string> intermediatePair <- "Answer" :: "Accept";
						do propose message:cfp contents: [intermediatePair];
						write "(" + name + "): " + "Accept this offer of " + cfp.sender + "My budget is " + budget;
					}
				}
				match "End" {
					numberOfAuctionParticipated <- numberOfAuctionParticipated - 1;
					if (numberOfAuctionParticipated = 0) {
						 budget <- rnd(1000, 2000);
					}
				}
   				default {
				
				} 
			}
		}
	}
	
	reflex winAuction when: length(accept_proposals) > 0 {
		loop accepted over: accept_proposals {
		}
	}
	
	reflex loseAuction when: length(reject_proposals) > 0 {
		loop rejected over: reject_proposals {
		}
	}
	
	bool shouldAcceptCurrentPrice(int currentPrice) {
		if (budget < currentPrice) {
			return false;
		}
		return true;
	}
	
	bool shouldParticipateAuction(string auctionObject) {
		list<string> sameObjectList <- interests where(each = auctionObject);
		if (!empty(sameObjectList)) {
			return true;
		}
		return false;
	}
}

species Auctioneer skills: [fipa] {
	aspect base {
		draw circle(3) color: rgb("green");
	}
	
	string status;
	list<agent> participants <- [];
	Bidder winner <- nil;
	int currentPrice;
	int minimumPrice;
	bool hasNotified;
	bool hasGivenStartPrice;
	string acutionObject;
	
	init {
		do restoreDefaults;
	}
	
	action restoreDefaults {
		status <- "Init";
		// It is necessary to ensure that the current price is higher than the minimum price during initialization.
		currentPrice <- rnd(1500, 2000);
		minimumPrice <- rnd(500, 1200);
		// By default, all bidders are participants at the start.
		participants <- list(Bidder);
		
		hasNotified <- false;
		hasGivenStartPrice <- false;
		winner <- nil;
	}
	
	reflex actionBasedOnCurrentStatus {
		switch status { 
   			match "Init" {
   				if (!hasNotified) {
   					do notifyBiddersAuctionStart;
   					hasNotified <- true;
   					write "(" + name + "): " + "The starting price for this auction is " + currentPrice + ", the minumin price is " + minimumPrice;
   				} else {
   					do adjustParticipantsList;
   				}
			} 
   			match "Bidding" {
   				do handleQuoteSituation;
			} 
   			default {
			} 
		}
	}
	
	action adjustParticipantsList {
		loop refusal over: refuses {
			list msg <- refusal.contents;
			pair msgPair <- msg[0];
			string msgType <- msgPair.key;
			if (msgType = "NoParticipate") {
				// If the bidder does not want to participate, remove it from the participants list.
				remove item:agent(refusal.sender) from: participants;
			}
		}
		if (length(participants) > 0) {
			// After deleting the bidders who do not want to participate, if the participants list is not empty, it means the auction has started.
			status <- "Bidding";
		} else {
			// If no one participates, terminate the auction, start a new auction.
			write "(" + name + "): " + "No one want to particapate";
			do restoreDefaults;
		}
	}
	
	action handleQuoteSituation {
		// If the bidders have not yet been informed of the starting bid, notify them.
		if (!hasGivenStartPrice) {
			do startOneBiddingRound;
			hasGivenStartPrice <- true;
			return;
		}
		loop answer over: proposes {
			if (winner = nil) {
				winner <- answer.sender;
				pair<string, int> intermediatePair <- "Price" :: currentPrice;
				do accept_proposal message: answer contents: [intermediatePair];
			} else {
				do reject_proposal message: answer contents: ["You're almost there."];
			}
		}
		if (winner = nil) {
			currentPrice <- currentPrice - rnd(300);
			if (currentPrice < minimumPrice) {
				write "(" + name + "): " + "The price is too low, stop the auction.";
				do restoreDefaults;
				return;
			} else {
				write "(" + name + "): " + "The auction price has dropped to " + currentPrice;
				do startOneBiddingRound;
			}
		} else {
			// Notify all bidders of the auction results.
			write "(" + name + "): " + "The winner of this auction is " + winner.name;
			pair<string, string> intermediatePair <- "End" :: "A winner has been found, stop this auction.";
			do start_conversation to: participants protocol: 'fipa-contract-net' performative: 'cfp' contents: [intermediatePair];
			do restoreDefaults;
		}
	}
	
	action notifyBiddersAuctionStart {
		// Tell all bidders that an auction has started.
		pair<string, string> intermediatePair <- "Notify" :: acutionObject;
		do start_conversation to: participants protocol: 'fipa-contract-net' performative: 'cfp' contents: [intermediatePair];
	}
	
	action startOneBiddingRound {
		// Tell all bidders the current price.
		pair<string, int> intermediatePair <- "Price" :: currentPrice;
		do start_conversation to: participants protocol: 'fipa-contract-net' performative: 'cfp' contents: [intermediatePair];
	}
	
}

experiment AuctionSimulation type:gui {
	output {
		display auctionDisplay {
			species Bidder aspect: base;
			species Auctioneer aspect: base;
		}
	}
}
