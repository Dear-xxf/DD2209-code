/**
* Name: Festival
* Based on the internal empty template. 
* Author: JKX & CFY
* Tags: 
*/


model Festival

global {
	int numberOfPeople <- 10; 
	int numberOfStore <- 4 ; 
	int numberOfInformationCenter <- 1;
	int numberOfcop <- 1;
	
	float distanceThreshold <- 8.0;
	
	init{
		create Guest number: numberOfPeople; 
		create Store number: numberOfStore;
		create InformationCenter number: numberOfInformationCenter;
		create cop number: numberOfcop; 
	}
}

species cop skills: [moving]{
	
	aspect base{
		rgb agentColor <- rgb("black");
	    draw triangle(7) color:agentColor;
	}
	
	// a list of bad guests
	list<Guest> nameList <- [];
	
	// Called by the information center to add bad performers to the list
	action addBadBehaviourName(Guest guest){
		list<Guest> samePersonList <- nameList where(each = guest);
		if (length(samePersonList) = 0){
			nameList <- nameList + [guest];
		} else {}
	}
	// When there is a value on the list, hunt for the first guest on the list
	reflex when:length(nameList) != 0 {
		if(nameList[0] = nil){
			nameList <- nameList where(each != nil);
			return;
		}
		do goto target:nameList[0].location speed:20.0;
		if (location distance_to nameList[0].location < distanceThreshold) {
			Guest guest <- nameList[0];
			ask guest {
				do die;
			}
			nameList <- nameList where(each != guest);
		}
	}
	
}

species Guest skills: [moving]{
	// Initial hunger and thirst values, which decrease over time
	float originHungryLevel <- 150.0;
	float originThirstyLevel <- 150.0;
	float hungryLevel <- originHungryLevel;
   	float thirstyLevel <- originThirstyLevel;
   	// Record whether the guest is hungry or thirsty
   	bool isHungry <- false;
	bool isThirsty <- false;

	// Target Store Location
	point targetStoreLocation;
	// The loaction of informationCenter
	point informationCenterLocation;
	
	/* 
	 * When the information center reports that there is no suitable store, wait in the information center for the store to be replenished.
	 * "shouldWaitForSupply" indicates whether to enter this state. 
	 */ 
	bool shouldWaitForSupply <- false;
	
	// Challenge 2: "badBehaviour" Record whether a person's performance deteriorates.
	bool badBehaviour <- false; 
	
	aspect base{
		rgb agentColor <- rgb("green");
		
		if (isHungry and isThirsty){
			agentColor <- rgb("red");             
		} else if (isHungry){
			agentColor <- rgb("yellow");
		} else if (isThirsty){
			agentColor <- rgb("blue");
		}
		if (badBehaviour){
			agentColor <- rgb("black");
		}
		draw circle(1.5) color: agentColor;
	}
	
	reflex badBehaviour when:badBehaviour = false {
		if (flip(0.05)) {
			badBehaviour <- true;
		}
	}
	
	reflex getInformationCenter {
		if (informationCenterLocation = nil) {
			ask InformationCenter {
				myself.informationCenterLocation <- location;
			}
		}
	}
	
	// Hunger and thirst levels ​​decrease over time.
	reflex decreaseStatusLevel{
      if (hungryLevel > 0) {
		int hungerDecrease <- rnd(15);
        hungryLevel <- hungryLevel - hungerDecrease;
      }
      if (hungryLevel <= 70) {
        isHungry <- true;
      }
      
      if (thirstyLevel > 0) {
		int thirstyDecrease <- rnd(15);
        thirstyLevel <- thirstyLevel - thirstyDecrease;
      }
      if (thirstyLevel <= 70) {
        isThirsty <- true;
      }
   }
   
   reflex waitForSupply when:shouldWaitForSupply = true{
   		do interactWithInformationCenter;
   }
   
	reflex move{
		if (isHungry or isThirsty) {
			if (targetStoreLocation = nil) {
				do moveToInformationCenter;
			} else {
				do moveToStore;
			}
		} else {
			do wander speed: 5.0;
		}
	}
	
	// Go to store.
	action moveToStore {
		if ((location distance_to targetStoreLocation) < distanceThreshold) {
			Store closestStore <- Store closest_to(self);
			ask closestStore {
				bool isSuccess <- refresh(myself);
			}
		} else {
			do goto target: targetStoreLocation speed:10.0;
		}
	}
	
	// Go to information center.
	action moveToInformationCenter{
		do goto target: informationCenterLocation speed:10.0;
		if ((location distance_to informationCenterLocation) < distanceThreshold) {
			do interactWithInformationCenter;
		}
	}
   
   /*
    * Interact with the information center to get the next decision.
    * It could be to get the coordinates and go to the store; it could also be to wait until a store is restocked.
    */ 
	action interactWithInformationCenter{
		write "The person go to the InformationCenter";
		ask InformationCenter {
			point des;
			if (myself.isHungry and myself.isThirsty) {
				// If the person is hungry and hunger is more severe than thirst
				des <- getLocationByStatus(myself, "both"); 
			} else if (myself.isHungry){
				des <- getLocationByStatus(myself, "hunger"); 
			} else {
				des <- getLocationByStatus(myself, "thirst");
			}
			if (des = nil) {
				myself.shouldWaitForSupply <- true;
			} else {
				myself.shouldWaitForSupply <- false;
				myself.targetStoreLocation <- des;
			}
		}
	}
	
	bool reportBehavior{
		return badBehaviour;
	}
}

species Store{                       
	aspect base{
		rgb agentColor <- rgb("lightgray");
		if(foodSupply > 0 and drinkSupply >0) {
			agentColor <- rgb("purple");
		} else if(drinkSupply > 0) {
			agentColor <- rgb("orange");
		} else if (foodSupply > 0){
			agentColor <- rgb("darkblue");
		} else{}
		draw square(3) color: agentColor;
	}
	
	// Quantity of food and drinks
	int foodSupply <- 0;
	int drinkSupply <- 0;
	// Time required for stock
	int foodRestockTimeSlot <- 0;
	int drinkRestockTimeSlot <- 0;
	
	init {
		foodSupply <- rnd(50);
		drinkSupply <- rnd(50);
	}
	
	reflex when:foodSupply = 0 {
		foodRestockTimeSlot <- foodRestockTimeSlot + 1;
		if (foodRestockTimeSlot = 10) {
			foodSupply <- rnd(50);
			foodRestockTimeSlot <- 0;
		}
	}
	
	reflex when:drinkSupply = 0{
		drinkRestockTimeSlot <- drinkRestockTimeSlot + 1;
		if (drinkRestockTimeSlot = 10) {
			drinkSupply <- rnd(50);
			drinkRestockTimeSlot <- 0;
		}
	}
	
	bool refresh(Guest guest){
		if (foodSupply = 0 and drinkSupply = 0) {
			guest.targetStoreLocation <- nil;
			return false;
		}
		if (foodSupply > 0 and guest.isHungry) {
			guest.hungryLevel <- guest.originHungryLevel;
			guest.isHungry <- false;
			foodSupply <- foodSupply - 1;
		}
		if (drinkSupply > 0 and guest.isThirsty) {
			guest.thirstyLevel <- guest.originThirstyLevel;
			guest.isThirsty <- false;
			drinkSupply <- drinkSupply - 1;
		}
		guest.targetStoreLocation <- nil;
		return guest.isHungry or guest.isThirsty;
	}
}

species InformationCenter{
	aspect base{
		rgb agentColor <- rgb("lightpink");
		draw square(5) color: agentColor ;
	}
	list<Store> allStores <- [];
	list<point> storeLocation <- [];
	list<Guest> badBehaviourList <- [];
	init{
		ask Store {
			Store currentStore <- self;
			point currentLocation <- location;
			ask InformationCenter {
				allStores <- allStores + [currentStore];
                storeLocation <- storeLocation + [currentLocation];
            }
    	}
	}
        
     point getLocationByStatus(Guest guest, string type){
     	do checkTheBehavior(guest);
     	bool needBoth <- (type = "both") ? true : false;
     	bool needFood <- (type = "hunger") ? true : false;
     	list<Store> potentialStores <- [];
     	if (needBoth){
     		potentialStores <- allStores where (each.foodSupply > 0 and each.drinkSupply > 0);
     		if (length(potentialStores) = 0) {
//     			write "No store have both food and drink";
				// If there are no stores that provide both food and drinks, give priority to stores that provide food.
     			needBoth <- false;
     			needFood <- true;
     		}
     	}
     	if (needFood) {
     		potentialStores <- allStores where (each.foodSupply > 0);
     		if (length(potentialStores) = 0) {
//     			write "No store have food";
     			return nil;
     		}
		} else {
			potentialStores <- allStores where (each.drinkSupply > 0);
			if (length(potentialStores) = 0) {
//     			write "No store have drink";
     			return nil;
     		}
		}
		Store closestStore <- potentialStores closest_to(guest.location);
   	 	return closestStore.location;
   	 }
   	 
   	 // Challenge 2: Check for bad behavior when guests arrive.
   	  action checkTheBehavior(Guest guest){
   	 	ask guest{
   	 		bool behavior <- reportBehavior();
   	 		if(behavior){
   	 			ask InformationCenter{
   	 				badBehaviourList <- badBehaviourList + [guest];
   	 				do reportNameToCop;
   	 			}
   	 		}
   	 	}
   	 }
   	 
   	 // Challenge 2: Report bad behavior to the police.
   	  action reportNameToCop{
   	  	ask cop {
   	  		do addBadBehaviourName(myself.badBehaviourList[length(myself.badBehaviourList) - 1]);
   	  	}
   	  }
}

experiment festivalSimulation type: gui{
	output{
		display festivalDisplay{
			species Guest aspect:base;
			species Store aspect:base;
			species InformationCenter aspect: base;
			species cop aspect: base;
		}
	}
}