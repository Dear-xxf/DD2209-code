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
	}	
}

species Guest skills: [fipa, moving] {
    float lightshowPreference <- rnd(0.0, 1.0);
    float speakersPreference <- rnd(0.0, 1.0);
    float musicPreference <- rnd(0.0, 1.0);
    float distanceThreshold <- 8.0;
    
    Stage chosenStage <- nil;
    
    aspect base {
		rgb agentColor <- rgb("green");
      	draw circle(1) color: agentColor;
	}
	
	init {
		write "(" + name + "): " + "My preferences are " + "lightshowPreference: " + lightshowPreference + "speakersPreference: " + speakersPreference + "musicPreference:" + musicPreference;
	}
	
	reflex receiveAnswers when: chosenStage = nil and !empty(agrees) {
		float maxUtility <- -1.0;
        loop agree over: agrees {
        	list msg <- agree.contents;
			float lightshowQuality <- float(msg[0]);
			float speakersQuality <- float(msg[1]);
			float musicQuality <- float(msg[2]);
			float utility <- lightshowPreference * lightshowQuality + speakersPreference * speakersQuality + musicPreference * musicQuality;
			write "(" + agree.sender + "):" + "utility is " + utility;
			if (utility > maxUtility) {
				maxUtility <- utility;
				chosenStage <- agree.sender;
			}
        }
        write "The max utility is " + maxUtility + " belongs to " + chosenStage;
    }
    
    reflex receiveInforms when:!empty(informs){
		loop inform over: informs {
            if (inform.contents[0] = "End" and inform.sender = chosenStage) {
            	write "--------------------";
    			write "A whole new choose start.";
    			chosenStage <- nil;
            }
        }
	}
    
    reflex sendQueries when:chosenStage = nil {
    	do start_conversation to:list(Stage) protocol: "fipa-query" performative: "query" contents:["Preferences"];
    }
    
    reflex travel when: chosenStage != nil and (location distance_to (chosenStage.location) > distanceThreshold) {
    	do goto target: chosenStage.location speed:5.0;
    }
	
}

species Stage skills: [fipa] {
    Act currentAct <- nil;
    int existTime <- 0;
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
    }
    
    reflex endAct when:currentAct != nil{
    	existTime <- existTime + 1;
    	if (existTime >= currentAct.expiryTime) {
    		
    		
    		do start_conversation to:list(Guest) protocol: "fipa-contract-net" performative: "inform" contents:["End"];
    		do start_conversation to:[currentAct] protocol: "fipa-contract-net" performative: "inform" contents:["End"];

    		do beginAct;
    		existTime <- 0;
    		write "(" + name + "):" + "The current act expires, and a new act is generated as " + currentAct.name;
    	}
    }
}

species Act skills: [fipa] {
    float lightshowQuality <- rnd(0.0, 1.0);
    float speakersQuality <- rnd(0.0, 1.0);
    float musicQuality <- rnd(0.0, 1.0);
    int expiryTime <- rnd(20, 30);
    
    init {
    	write "(" + name + "): The current act gets " + "lightshowQuality:" + lightshowQuality + "  speakersQuality:" + speakersQuality + "  musicQuality:" + musicQuality;
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
