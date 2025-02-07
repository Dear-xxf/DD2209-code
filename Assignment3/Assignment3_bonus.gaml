/**
* Name: Assignment3task2
* Based on the internal empty template. 
* Author: Dearcfy
* Tags: 
*/


model positionSpeaker

global {
	int numberOfGuest <- 5;
    int numberOfStages <- 3;
	
	init {
		create Guest number:numberOfGuest;
        create Stage number:numberOfStages;
        
        Stage[0].agentColor <- rgb("red");
        Stage[1].agentColor <- rgb("yellow");
        Stage[2].agentColor <- rgb("blue");
        
        Stage[0].location <- {10, 10};
		Stage[1].location <- {50, 80};
		Stage[2].location <- {20, 70};
        
        Guest[0].leader <- true;
	}	
}

species Guest skills: [fipa, moving] {
    float lightshowPreference <- rnd(0.0, 1.0);
    float speakersPreference <- rnd(0.0, 1.0);
    float musicPreference <- rnd(0.0, 1.0);
    float crowdPreference <- rnd(-1.0, 1.0);
    float distanceThreshold <- 8.0;
    
    float maxUtility <- -1.0;
    
    Stage chosenStage <- nil;
    
    bool leader <- false;
    float globalUtility <- -1.0;
    map<Stage, list<Guest>> informationMap <- [];
    list<Stage> stages <- [];
    
    string state <- "none";
    
    aspect base {
		rgb agentColor <- rgb("green");
      	draw circle(1) color: agentColor;
	}
	
	init {
		write "(" + name + "): " + "My preferences are " + "lightshowPreference: " + lightshowPreference + "speakersPreference: " + speakersPreference + "musicPreference:" + musicPreference;
	}
	
	reflex receiveStageAnswers when: chosenStage = nil and !empty(agrees) and state = "none" {
		write "(" + name + "): Get stage information.";
        loop agree over: agrees {
        	list msg <- agree.contents;
			float utility <- calculateUtility(agree.sender);
//			write "(" + agree.sender + "):" + "utility is " + utility;
			if (utility > maxUtility) {
				maxUtility <- utility;
				chosenStage <- agree.sender;
			}
        }
        state <- "collect";
    }
    
    float calculateUtility (Stage stage) {
    	return lightshowPreference * stage.currLightshowQuality + speakersPreference * stage.currSpeakersQuality + musicPreference * stage.currMusicQuality;
    }
    
    reflex receiveGuestAnswers when: leader and !empty(proposes) and state = "wait" {
        write "Leader got information from all other agents";
    	loop propose over: proposes {
    		Guest currGuest <- Guest(propose.contents[0]);
    		Stage currChosenStage <- Stage(propose.contents[1]);
    		float currMaxUtility <- float(propose.contents[2]);
    		float currCrowdPreference <- float(propose.contents[3]);
    		write("- " + currGuest.name + " with utility " + currMaxUtility + " and crowd preference " + currCrowdPreference);
    		do recordGuestInformation(currGuest, currChosenStage);
    	}
    	// Add information of self;
    	do recordGuestInformation(self, chosenStage);
    	write "Imformation Map before optimization is" + informationMap;
    	
    	globalUtility <- calculateGlobalUtility();
    	write "Global utility before optimization is " + globalUtility;
    	
    	do optimizeGlobalUtility();
    	write "Final global utility is " + globalUtility;
    	write "Imformation Map after optimization is" + informationMap;
    	
    	loop finalStage over: stages {
    		list<Guest> guestListAtThisStage <- informationMap[finalStage];
    		loop eachGuest over: guestListAtThisStage {
    			do start_conversation to: [eachGuest] protocol: 'fipa-contract-net' performative: 'inform' contents: ['goto', finalStage];
    		}
    	}
    }
    
    reflex collectGuestInformation when: state = "collect" {
    	if (leader) {
    		write "Leader start collect chosen target of others.";
    		list<agent> targets <- list(Guest) where(each != self);
	    	do start_conversation to: targets protocol: 'fipa-contract-net' performative: 'cfp' contents: ['target'];
	    	state <- "wait";
    	}
    }
    
    reflex receiveFinalTarget when: state = "wait" and !empty(informs) {
    	loop infrom over: informs {
            if (infrom.contents[0] = 'goto') {
                chosenStage <- Stage(infrom.contents[1]);
                write "(" + name + "): Final stage is " + chosenStage;
                state <- "resolved";
            }
        }
    }
    
    action recordGuestInformation(Guest guest, Stage stage) {
		if (not (stages contains stage)) {
			add stage to: stages;
		}
		list<Guest> guestListAtThisStage <- informationMap[stage];
		if (guestListAtThisStage = nil) {
			guestListAtThisStage <- [];
		}
		add guest to: guestListAtThisStage;
		informationMap[stage] <- guestListAtThisStage;
	}
	
	float calculateGlobalUtility {
		float value <- 0.0;
    	loop stage over: stages {
    		list<Guest> guestListAtThisStage <- informationMap[stage];
    		if (guestListAtThisStage = nil or empty(guestListAtThisStage)) {
    			continue;
    		}
    		float crowd <- length(guestListAtThisStage) / numberOfGuest;
    		loop guest over: guestListAtThisStage {
    			float guestUtility <- guest.calculateUtility(stage);
    			float guestCrowdUtility <- guest.crowdPreference * crowd;
    			value <- value + guestUtility + guestCrowdUtility;
    		}
    	}
    	return value;
    }
    
    action optimizeGlobalUtility {
    	loop guest over:list(Guest) {
    		Stage bestStage <- nil;
    		float bestUtility <- -1.0;
    		loop stage over: stages {
    			list<Guest> guestListAtThisStage <- informationMap[stage];
    			float crowd <- length(guestListAtThisStage) / numberOfGuest;
    			float crowdUtility <- guest.crowdPreference * crowd;
    			float utility <- guest.calculateUtility(stage);
    			if (utility + crowdUtility > bestUtility) {
    				bestUtility <- utility + crowdUtility;
    				bestStage <- stage;
    			}
    		}
    		if (bestStage = guest.chosenStage) {
    			continue;
    		} else {
    			Stage stageBefore <- nil;
    			Stage stageAfter <- nil;
    			loop stage over: stages {
    				list<Guest> guestListAtThisStage <- informationMap[stage];
    				if (stage = guest.chosenStage) {
    					remove guest from: guestListAtThisStage;
    					stageBefore <- stage;
    				}
    				if (stage = bestStage) {
    					add guest to:guestListAtThisStage;
    					stageAfter <- stage;
    				}
    			}
    			float currGlobalUtility <- calculateGlobalUtility();
    			if (currGlobalUtility > globalUtility) {
    				globalUtility <- currGlobalUtility;
    				write "(" + guest.name + ")'s preference is beneficial to global utility. Current global utility is " + currGlobalUtility;
    			} else {
    				write "(" + guest.name + ")'s preference is harmful to global utility. Reject adjustment.";
    				list<Guest> guestListAtStageBefore <- informationMap[stageBefore];
    				list<Guest> guestListAtStageAfter <- informationMap[stageAfter];
    				add guest to: guestListAtStageBefore;
    				remove guest from: guestListAtStageAfter;
    			}
    		}
    	}
    	return informationMap;
    }
    
    reflex receiveQueries when:chosenStage != nil and !empty(cfps) and state = "collect" {
    	write "(" + name + ") receive query about  target.";
        loop cfp over: cfps {
            if (cfp.contents[0] = 'target') {
                string _ <- cfp.contents;
                do propose message: cfp contents: [self, chosenStage, maxUtility, crowdPreference];
                write "(" + name + ") wanna goto " + chosenStage + " before optimization.";
                state <- "wait";
            }
        }
    }
    
    reflex receiveInforms when:!empty(informs){
		loop inform over: informs {
            if (inform.contents[0] = "End" and inform.sender = chosenStage) {
    			chosenStage <- nil;
    			state <- "none";
    			maxUtility <- -1.0;
    			if (leader) {
    				globalUtility <- -1.0;
   					informationMap <- [];
    				stages <- [];
    			}
            }
        }
	}
    
    reflex sendQueries when:chosenStage = nil {
    	do start_conversation to:list(Stage) protocol: "fipa-query" performative: "query" contents:["Preferences"];
    }
    
    reflex travel when: state = "resolved" and chosenStage != nil and (location distance_to (chosenStage.location) > distanceThreshold) {
    	do goto target: chosenStage.location speed:5.0;
    }
	
}

species Stage skills: [fipa] {
    Act currentAct <- nil;
    int existTime <- 0;
    int intervalTime <- 0;
    
    float currLightshowQuality <- 0.0;
    float currSpeakersQuality <- 0.0;
    float currMusicQuality <- 0.0;
    
    rgb agentColor <- rgb("red");
    aspect base {
        draw square(3) color: agentColor;
    }
    
    init {
    	do beginAct;
    }
    
    reflex acceptQuery when: !(empty(queries)) {
        loop query over: queries {
            if (currentAct != nil) {
                do agree message: query contents: [currentAct.lightshowQuality, currentAct.speakersQuality, currentAct.musicQuality];
            }
        }
    }
    
    action beginAct {
    	create Act returns: createdAct;
    	currentAct <- createdAct[0];
    	currLightshowQuality <- currentAct.lightshowQuality;
    	currSpeakersQuality <- currentAct.speakersQuality;
    	currMusicQuality <- currentAct.musicQuality;
    	write "(" + name + "):" + "The current act expires, and a new act is generated as " + currentAct.name;
    }
    
    reflex endAct when:currentAct != nil{
    	existTime <- existTime + 1;
    	if (existTime >= currentAct.expiryTime) {
    		
    		
    		do start_conversation to:list(Guest) protocol: "fipa-contract-net" performative: "inform" contents:["End"];
    		do start_conversation to:[currentAct] protocol: "fipa-contract-net" performative: "inform" contents:["End"];

			do beginAct;
    		existTime <- 0;
    	}
    }
}

species Act skills: [fipa] {
    float lightshowQuality <- rnd(0.0, 1.0);
    float speakersQuality <- rnd(0.0, 1.0);
    float musicQuality <- rnd(0.0, 1.0);
//    int expiryTime <- rnd(50, 70);
	int expiryTime <- 30;
    
    init {
//    	write "(" + name + "): The current act gets " + "lightshowQuality:" + lightshowQuality + "  speakersQuality:" + speakersQuality + "  musicQuality:" + musicQuality;
    }

	reflex receiveInforms when:!empty(informs){
		loop inform over: informs {
            if (inform.contents[0] = "End") {
                do die;
            }
        }
	}

    aspect base {
        draw square(3) color: rgb("red");
    }
}

experiment positionSpeaker type:gui {
	output {
		display positionSpeakerDisplay {
			species Guest aspect:base;
			species Stage aspect:base;
		}
	}
}
