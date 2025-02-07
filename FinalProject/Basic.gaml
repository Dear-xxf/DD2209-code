/**
* Name: FinalProject
* Based on the internal empty template. 
* Author: Dearcfy & JKX
* Tags: 
*/


model FinalProject

global {
	int numberOfWealthy <- 5;
	int numberOfParty <- 15;
	int numberOfIntrovert <- 15;
	int numberOfRockFan <- 10;
	int numberOfThief <- 5;
	
	int happinessLevelOfIntrovert <- 0;
	int happinessLevelOfWealthy <- 0;
	int happinessLevelOfParty <- 0;
	int happinessLevelOfRockFan <- 0;
	int happinessLevelOfThief <- 0;
	
	int totalConversationTimes <- 0;
	int totalDenies <- 0;
	list<agent> allAgents;
	
	init {
		create Wealthy number:numberOfWealthy;
		create Introvert number:numberOfIntrovert;
		create Party number:numberOfParty;
		create RockFan number:numberOfRockFan;
		create Thief number:numberOfThief;
		allAgents <- get_all_instances(Person);
	}
	
	list<agent> get_all_instances(species<agent> spec) {
        return spec.population +  spec.subspecies accumulate (get_all_instances(each));
    }
}

species Person skills: [moving, fipa] {
	int thirstyLevel;
	int socialLevel;
	int musicPreference;
	
	point targetPoint;
	string status <- "wander";
	
	action resetParameter virtual: true;

	init {
		do resetParameter;
	}

	reflex checkStatus {
		if (targetPoint != nil) {
			return;
		}
		do resetParameter;
		int statusLevel <- thirstyLevel + socialLevel + musicPreference;
//		write "(" + name + ") statusLevel: " + statusLevel;
		if (statusLevel < 110) {
			status <- "thirsty";
			targetPoint <- {rnd(0, 33), rnd(0, 33)};
		} else if (statusLevel > 110 and statusLevel < 130) {
			status <- "wander";
			targetPoint <- {rnd(0, 100), rnd(0, 100)};
		} else if (statusLevel > 130 and statusLevel < 140) {
			status <- "talk";
			targetPoint <- {rnd(0, 33), rnd(67, 100)};
		} else {
			status <- "rock";
			targetPoint <- {rnd(67, 100), rnd(0, 33)};
		}
	}

	reflex checkQueries when:!empty(queries) {
		loop query over: queries {
			string messageType <- query.contents[0];
			switch messageType {
				match "BuyDrink" {
					if (thirstyLevel < 20 or socialLevel > 40) {
						totalConversationTimes <- totalConversationTimes + 1;
                		do agree message:query contents:["OKWithDrink"];
                	} else {
                		totalDenies <- totalDenies + 1;
                		do refuse message:query contents:["NoDrinks"];
                	}
				}
				match "Talk" {
					int vigilance <- checkPosition() = "Alley" ? 5 : 0;
					int socialLevelAfterEvaluation <- socialLevel - vigilance;
					if (socialLevelAfterEvaluation > 40) {
						totalConversationTimes <- totalConversationTimes + 1;
						do agree message:query contents:["OKWithTalk"];
					} else {
						totalDenies <- totalDenies + 1;
						do refuse message:query contents:["NoTalk"];
					}
				}
				match "Rock" {
					if (socialLevel > 45 or musicPreference > 45) {
						totalConversationTimes <- totalConversationTimes + 1;
						do agree message:query contents:["OKWithRock"];
					} else {
						totalDenies <- totalDenies + 1;
						do refuse message:query contents:["NoRock"];
					}
				}
			}
        }
	}
	
	reflex { 
		if (thirstyLevel > 0) {
			thirstyLevel <- thirstyLevel - 1;
		}
	}
	
	reflex moveToTarget {
		if (targetPoint = nil) {
			do wander speed:15.0;
			return;
		}
		do goto target:targetPoint speed:15.0;
	}
	
	reflex when:targetPoint != nil {
		if (self distance_to targetPoint < 5.0) {
			targetPoint <- nil;
		}
	}
	
	string checkPosition {
		switch festival_map({self.location.x, self.location.y}).color {
			match #yellow {
				return "Bar";
			}
			match #green {
				return "Party";
			}
			match #purple {
				return "Rock";
			}
			match #gray {
				return "Alley";
			}
			default {
				return "Normal";
			}
		}
	}
}

species Wealthy parent:Person {
	
	aspect base {
        draw square(3) color: rgb("gold");
    }
	action resetParameter {
		thirstyLevel <- rnd(30, 50);
		socialLevel <- rnd(30, 50);
		musicPreference <- rnd(30, 50);
	}
	
	reflex interactWithOthers when:!empty(allAgents at_distance 10) and (status = "talk" or status = "rock") {
		list<agent> nearbyPerson <- allAgents at_distance 10;
		Person selectedPerson <- Person(nearbyPerson[rnd(0, length(nearbyPerson) - 1)]);
		string currentPosition <- checkPosition();
		if (currentPosition = "Bar") {
			do start_conversation to: [selectedPerson] protocol: 'fipa-query' performative: 'query' contents: ["BuyDrink"];
		} else {
			do start_conversation to: [selectedPerson] protocol: 'fipa-query' performative: 'query' contents: ["Talk"];
		}
	}
	
	reflex when:!(empty(agrees)) {
		loop agree over: agrees {
			if (agree.contents[0] = "OKWithDrink") {
				write "(" + name + ") Someone accepted my invitation for a drink. I am happy.";
				happinessLevelOfWealthy <- happinessLevelOfWealthy + 1;
			}
		}
	}
	
	reflex when:!(empty(refuses)) {
		loop refuse over: refuses {
			if (refuse.contents[0] = "NoDrinks") {
				happinessLevelOfWealthy <- happinessLevelOfWealthy - 1;
			}
		}
	}
}

species Party parent:Person {
	
	aspect base {
        draw square(3) color: rgb("red");
    }

	action resetParameter {
		thirstyLevel <- rnd(30, 50);
		socialLevel <- rnd(35, 55);
		musicPreference <- rnd(30, 50);
	}
	
	reflex interactWithOthers when:!empty(allAgents at_distance 10) and (status = "talk" or status = "rock") {
		list<agent> nearbyPerson <- allAgents at_distance 10;
		Person selectedPerson <- Person(nearbyPerson[rnd(0, length(nearbyPerson) - 1)]);
		do start_conversation to: [selectedPerson] protocol: 'fipa-contract-net' performative: 'inform' contents: ["Talk"];
	}
	
	reflex crowdSituation {
		list<agent> nearbyPerson <- allAgents at_distance 10;
		if (length(nearbyPerson) >= 5 and checkPosition() = "Party") {
			write "(" + name + ") So many people here. I am happy.";
			happinessLevelOfParty <- happinessLevelOfParty + 1;
		} else if (length(nearbyPerson) = 0 and checkPosition() = "Party") {
			happinessLevelOfParty <- happinessLevelOfParty - 1;
		} else {}
	}
	
	reflex when:!(empty(agrees)) {
		loop agree over: agrees {
		}
	}
}

species Introvert parent:Person {
	int annoyanceLevel <- 0;
	
	aspect base {
        draw square(3) color: rgb("blue");
    }
	
	action resetParameter {
		thirstyLevel <- rnd(30, 50);
		socialLevel <- rnd(25, 45);
		musicPreference <- rnd(30, 50);
	}
	
	reflex interactWithOthers when:!empty(allAgents at_distance 10) and (status = "talk" or status = "rock") {
		list<agent> nearbyPerson <- allAgents at_distance 10;
		Person selectedPerson <- Person(nearbyPerson[rnd(0, length(nearbyPerson) - 1)]);
		do start_conversation to: [selectedPerson] protocol: 'fipa-contract-net' performative: 'inform' contents: ["Talk"];
	}
	
	reflex crowdSituation {
		list<agent> nearbyPerson <- allAgents at_distance 10;
		if (length(nearbyPerson) >= 6 and checkPosition() != "Bar") {
			write "(" + name + ") So many people here. I am unhappy.";
			happinessLevelOfIntrovert <- happinessLevelOfIntrovert - 1;
		} else if (length(nearbyPerson) = 0 and checkPosition() != "Bar") {
			happinessLevelOfIntrovert <- happinessLevelOfIntrovert + 1;
		} else {}
	}
	
	reflex when:!(empty(agrees)) {
		loop agree over: agrees {
		}
	}
}

species RockFan parent:Person {
	
	aspect base {
        draw square(3) color: rgb("orange");
    }
	
	action resetParameter {
		thirstyLevel <- rnd(30, 50);
		socialLevel <- rnd(30, 50);
		musicPreference <- rnd(35, 55);
	}
	
	reflex interactWithOthers when:!empty(allAgents at_distance 10) and (status = "talk" or status = "rock") {
		list<agent> nearbyPerson <- allAgents at_distance 10;
		Person selectedPerson <- Person(nearbyPerson[rnd(0, length(nearbyPerson) - 1)]);
		string currentPosition <- checkPosition();
		if (currentPosition = "Rock") {
			do start_conversation to: nearbyPerson  protocol: 'fipa-query' performative: 'query' contents: ["Rock"];
		} else {
			do start_conversation to: [selectedPerson] protocol: 'fipa-query' performative: 'query' contents: ["Talk"];
		}
	}
	
	reflex when:!(empty(agrees)) {
		loop agree over: agrees {
			if (agree.contents[0] = "OKWithRock") {
				happinessLevelOfRockFan <- happinessLevelOfRockFan + 1;
				write "(" + name + ") Let's rock!";
			}
		}
	}
	
	reflex when:!(empty(refuses)) {
		loop refuse over: refuses {
			if (refuse.contents[0] = "NoRock") {
				happinessLevelOfRockFan <- happinessLevelOfRockFan - 1;
				write "(" + name + ") Someone refuses the rock invitation.";
			}
		}
	}
}

species Thief parent:Person {
	
	aspect base {
        draw square(3) color: rgb("black");
    }
	
	action resetParameter {
		thirstyLevel <- rnd(30, 50);
		socialLevel <- rnd(30, 50);
		musicPreference <- rnd(30, 50);
	}
	
	reflex interactWithOthers when:!empty(allAgents at_distance 10) and (status = "talk" or status = "rock") {
		list<agent> nearbyPerson <- allAgents at_distance 10;
		int numberOfPeopleAroundMaximum <- checkPosition() = "Alley" ? 3 : 1;
		if (length(nearbyPerson) > numberOfPeopleAroundMaximum) {
			write "(" + name + ") So many people. I'm afraid of being discovered.";
			return;
		}
		Person selectedPerson <- Person(nearbyPerson[rnd(0, length(nearbyPerson) - 1)]);
		do start_conversation to: [selectedPerson] protocol: 'fipa-query' performative: 'query' contents: ["Talk"];
	}
	
	reflex when:!(empty(agrees)) {
		loop agree over: agrees {
			if (agree.contents[0] = "OKWithTalk") {
				happinessLevelOfThief <- happinessLevelOfThief + 1;
				write "(" + name + ") Haha, I stole something successfully.";
			}
		}
	}
	
	reflex when:!(empty(refuses)) {
		loop refuse over: refuses {
			if (refuse.contents[0] = "NoTalk") {
				happinessLevelOfThief <- happinessLevelOfThief - 1;
			}
		}
	}
}


grid festival_map width: 3 height: 3 neighbors: 8 {
	rgb get_color {
		if (grid_x = 0) {
			if (grid_y = 0) {
				return #yellow;
			} else if (grid_y = 2) {
				return #green;
			} else {
				return #white;
			}
		} else if (grid_x = 2) {
			if (grid_y = 0) {
				return #purple;
			} else if (grid_y = 2) {
				return #gray; 
			} else {
				return #white;
			}
		} else {
			return #white;
		}
	}
    rgb color <- get_color();
}

experiment festival type: gui {
	output {
		display fesitival_map type: 2d{
			grid festival_map border: #black;
			species Wealthy aspect: base;
			species Introvert aspect: base;
			species RockFan aspect: base;
			species Party aspect: base;
			species Thief aspect: base;
		}
		
		display chart {
        	chart "Chart1" type: series style: spline {
     			data "Total amount of conversations" value: totalConversationTimes color: #black;
        		data "Total amount of denied conversations" value: totalDenies color: #red;
        		data "Happiness level of Wealthy" value: happinessLevelOfWealthy color: #orange;
//        		data "Happiness level of Party" value: happinessLevelOfParty color: #green;
//        		data "Happiness level of Introvert" value: happinessLevelOfIntrovert color: #yellow;
//        		data "Happiness level of RockFan" value: happinessLevelOfRockFan color: #purple;
//        		data "Happiness level of Thief" value: happinessLevelOfThief color: #grey;
        	}
		}
	}
}

