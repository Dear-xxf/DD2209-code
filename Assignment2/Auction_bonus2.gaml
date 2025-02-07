/**
* Name: Auction
* Based on the internal empty template. 
* Author: Dearcfy
* Tags: 
*/


model Auction

global {
	int numberOfBidders <- 3;
	string auctionType <- "Vickrey";
	init {
		create Bidder number: numberOfBidders;
		create Auctioneer;
	}
}

species Bidder skills: [fipa] {
	aspect base {
		draw square(5) color: rgb("red");
	}
	int budget;
	init {
		budget <- rnd(1000, 2000);
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
				}
				match "Price" {
					int currentPrice <- int(msgPair.value);
					bool shouldAccept <- shouldAcceptCurrentPrice(currentPrice);
					if (!shouldAccept) {
						pair<string, string> intermediatePair <- "Answer" :: "Reject";
						do refuse message:cfp contents: [intermediatePair];
						write "(" + name + "): " + "Reject this offer. " + "My budget is " + budget;
					} else {
						int nextRoundBidding <- 0;
						switch auctionType {
							match "English" {
								nextRoundBidding <- addBiddingInEnglishAuction(currentPrice);
								pair<string, int> intermediatePair <- "Answer" :: nextRoundBidding;
								do propose message:cfp contents: [intermediatePair];
								write "(" + name + "): " + "Accept this offer. " + "My price is " + nextRoundBidding;
							}
							match "Dutch" {
								pair<string, string> intermediatePair <- "Answer" :: "Accept";
								do propose message:cfp contents: [intermediatePair];
								write "(" + name + "): " + "Accept this offer. " + "My budget is " + budget;
							}
							match "Sealed" {
								pair<string, int> intermediatePair <- "Answer" :: budget;
								do propose message:cfp contents: [intermediatePair];
								write "(" + name + "): " + "Accept this offer. " + "My price is " + budget;
							}
							match"Vickrey" {
								pair<string, int> intermediatePair <- "Answer" :: budget;
								do propose message: cfp contents: [intermediatePair];
								write "(" + name + "): " + "Accept this offer. " + "My price is " + budget;
							}
						}
					}
				}
				match "End" {
					budget <- rnd(1000, 2000);
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
	
	reflex getInform when: length(informs) > 0 {
		loop inform over: informs {
		}
	}
	
	bool shouldAcceptCurrentPrice(int currentPrice) {
		if (budget < currentPrice) {
			return false;
		}
		return true;
	}
	
	int addBiddingInEnglishAuction(int currentPrice) {
		int balance <- budget - currentPrice;
		return currentPrice + rnd(balance);
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
		if (auctionType = "English") {
			currentPrice <- minimumPrice;
		}
		if (auctionType = "Sealed" or auctionType = "Vickrey") {
			currentPrice <- 0;
		}
		// By default, all bidders are participants at the start.
		participants <- list(Bidder);
		
		acutionObject <- "object";
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
			do startOneBiddingRound(participants);
			hasGivenStartPrice <- true;
			return;
		}
		
		switch auctionType {
			match "English" {
				do executeEnglishAuction;
			} 
			match "Dutch" {
				do executeDutchAuction;
			}
			match "Sealed" {
				do executeSealedAuction;
			}
			match "Vickrey"{
				do executeVickreyAuction;
			}
		}
	}
	
	action notifyBiddersAuctionStart {
		// Tell all bidders that an auction has started.
		pair<string, string> intermediatePair <- "Notify" :: acutionObject;
		do start_conversation to: participants protocol: 'fipa-contract-net' performative: 'cfp' contents: [intermediatePair];
	}
	
	action startOneBiddingRound(list<agent> receivers) {
		// Tell all bidders the current price.
		pair<string, int> intermediatePair <- "Price" :: currentPrice;
		do start_conversation to: receivers protocol: 'fipa-contract-net' performative: 'cfp' contents: [intermediatePair];
	}
	
	action executeEnglishAuction {
		if (empty(proposes) and winner = nil) {
			write "(" + name + "): " + "No one wants this object.";
			do restoreDefaults;
		} else if (empty(proposes) and winner != nil) {
			write "(" + name + "): " + "The winner of this auction is " + winner.name;
			pair<string, string> intermediatePair <- "End" :: "A winner has been found, stop this auction.";
			do start_conversation to: participants protocol: 'fipa-contract-net' performative: 'cfp' contents: [intermediatePair];
			do restoreDefaults;
		} else {
			loop propose over: proposes {
				list msg <- propose.contents;
				pair msgPair <- msg[0];
				int price <- int(msgPair.value);
				if (price > currentPrice) {
					currentPrice <- price;
					winner <- propose.sender;
				}
			}
			list otherBidders <- participants where(each != winner);
			do startOneBiddingRound(otherBidders);
		}
		// For rejected feedback, traverse but do not do anything.
		if (!empty(refuses)) {
			loop refuse over: refuses {
			}
		}
	}
	
	action executeDutchAuction {
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
				do startOneBiddingRound(participants);
			}
		} else {
			// Notify all bidders of the auction results.
			write "(" + name + "): " + "The winner of this auction is " + winner.name;
			pair<string, string> intermediatePair <- "End" :: "A winner has been found, stop this auction.";
			do start_conversation to: participants protocol: 'fipa-contract-net' performative: 'cfp' contents: [intermediatePair];
			do restoreDefaults;
		}
	}
	
	action executeSealedAuction {
		int maximumPrice <- 0;
		loop propose over: proposes {
			list msg <- propose.contents;
			pair msgPair <- msg[0];
			int price <- int(msgPair.value);
			if (price > maximumPrice) {
				maximumPrice <- price;
				winner <- propose.sender;
			}
		}
		if (winner != nil) {
			write "(" + name + "): " + "The winner of this auction is " + winner.name;
			pair<string, string> intermediatePair <- "End" :: "A winner has been found, stop this auction.";
			do start_conversation to: participants protocol: 'fipa-contract-net' performative: 'cfp' contents: [intermediatePair];
			do restoreDefaults;
		}
	}
	
	action executeVickreyAuction{
		list<list> PriceList ;
		winner <- nil;
		if(!empty(proposes)){
			loop proMsg over: proposes{
				list msg <- proMsg.contents;
				pair msgPair <- msg[0];
				int price <- int(msgPair.value);
				write '(Time ' + time + '): ' + agent(proMsg.sender).name + ' Price is : ' + price;
				add [agent(proMsg.sender), price, proMsg] to: PriceList;
			}
			int lastIndex <- length(PriceList) - 1;
			int secondLastIndex <- max(0, lastIndex - 1);
			list<list> sortedBids <- PriceList sort_by (int(each at 1));
			Bidder bestBidder <- Bidder((sortedBids at lastIndex) at 0);
			int secondBestPrice <- int((sortedBids at secondLastIndex) at 1);
			
			loop proMsg over: PriceList accumulate (message(each at 2)){
				if (proMsg.sender = bestBidder){
					winner <- proMsg.sender;
					write "[" + name + "] Winner found, it is " + winner.name + " who has to pay " + secondBestPrice;
					do accept_proposal message: proMsg contents: ["Deal!!!!"];
				}else{
					do reject_proposal message: proMsg contents: ["Sorry, next time"];
				}
				string _ <- proMsg.contents;
			}
			winner <- bestBidder;
			pair<string, string> intermediatePair <- "End" :: "A winner has been found, stop this auction.";
			do start_conversation to: participants protocol: 'fipa-contract-net' performative: 'cfp' contents: [intermediatePair];
			do restoreDefaults;
		}
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
