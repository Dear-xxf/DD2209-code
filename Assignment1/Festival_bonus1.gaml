/**
* Name: Festival
* Based on the internal empty template. 
* Author: JKX & CFY
* Tags: 
*/


model Festival

global {
	int numberOfPeople <- 1; 
	int numberOfStore <- 4 ; 
	int numberOfInformationCenter <- 1;
	int numberOfcop <- 1;
	
	float distanceThreshold <- 8.0;
	
	init{
		create Guest number: numberOfPeople; 
		create Store number: numberOfStore;
		create InformationCenter number: numberOfInformationCenter;
		
		Store[0].location <- {10, 10};
		Store[1].location <- {50, 80};
		Store[2].location <- {20, 70};
		Store[3].location <- {80, 20};
		InformationCenter[0].location <- {50, 50};
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
	
	// Challenge 1: Memory records the stores visited recently and the types of items in the stores
	list<point> recentStoreLocation <- [];
	list<string> recentStoreType <- [];
	
	/* 
	 * When the information center reports that there is no suitable store, wait in the information center for the store to be replenished.
	 * "shouldWaitForSupply" indicates whether to enter this state. 
	 */ 
	bool shouldWaitForSupply <- false;
	
	// Challenge 1: Keep the speed the same and record the time required to go to the store to refill energy.
	int traveledTime <- 0;
	int hungryTimes <- 0;
	bool lastHungerStatus <- false;
	
	aspect base{
		rgb agentColor <- rgb("green");
		
		if (isHungry and isThirsty){
			agentColor <- rgb("red");             
		} else if (isHungry){
			agentColor <- rgb("yellow");
		} else if (isThirsty){
			agentColor <- rgb("blue");
		}
//		if (PersonBehaviour){
//			agentColor <- rgb("black");
//		}
		draw circle(1.5) color: agentColor;
	}
	
	/*
	 * When "lastHungerStatus" is not equal to "isHungry", it means that the hunger status has changed. 
	 * Two changes mean that after being hungry, the guest went to the store to get refreshed.
	 */
	reflex recordDifferentDistance when:lastHungerStatus != isHungry {
		lastHungerStatus <- isHungry;
		hungryTimes <- hungryTimes + 1;
		if (hungryTimes = 200) {
			write traveledTime;
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
   
   // Challenge 1: At each step, check the stores within the distance threshold and update the memory.
   reflex checkSurroundings {
   		list<Store> surroundingsStore <- Store where((each distance_to location) < distanceThreshold);
   		if (length(surroundingsStore) = 0) {
   			return;
   		}
   		loop i from:0 to:length(surroundingsStore) - 1{
   			list<point> sameLocation <- recentStoreLocation where ((each distance_to surroundingsStore[i].location) < distanceThreshold);
			ask surroundingsStore[i] {
				if (length(sameLocation) = 0) {
					do addInformationToGuestMemory(myself);
				} else {
					do modifyGuestMemory(myself);
				}
			}
   		}
   }
   
   reflex waitForSupply when:shouldWaitForSupply = true{
   		do interactWithInformationCenter;
   }
   
	reflex move{
		if (isHungry or isThirsty) {
			point shouldGoToRecentStore <- shouldGoToRecentStore();
//			if (shouldGoToRecentStore != nil) {
			// Ban the memory function.
			if (false) {
				targetStoreLocation <- shouldGoToRecentStore;
				do moveToStore;
			} else {
				if (targetStoreLocation = nil) {
					do moveToInformationCenter;
				} else {
					do moveToStore;
				}
			}
		} else {
			do wander speed: 15.0;
		}
	}
	
	// Challenge 1: If the return value is not nil, it means that the store in memory should be visited and the point coordinates will be returned.
	point shouldGoToRecentStore{
		if (length(recentStoreType) = 0) {
			return nil;
		}
		list<point> potentialStoreLocation <- [];
		loop i from: 0 to: length(recentStoreType) - 1{
			if (recentStoreType[i] = 'both') {
				potentialStoreLocation <- potentialStoreLocation + [recentStoreLocation[i]];
			} else if (isHungry and recentStoreType[i] = "food") {
				potentialStoreLocation <- potentialStoreLocation + [recentStoreLocation[i]];
			} else if (isThirsty and recentStoreType[i] = "drink") {
				potentialStoreLocation <- potentialStoreLocation + [recentStoreLocation[i]];
			} else {
				continue;
			}
		}
		if (length(potentialStoreLocation) = 0) {
			return nil;
		}
		return potentialStoreLocation closest_to location;
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
			traveledTime <- traveledTime + 1;
		}
	}
	
	// Go to information center.
	action moveToInformationCenter{
		do goto target: informationCenterLocation speed:10.0;
		traveledTime <- traveledTime + 1;
		if ((location distance_to informationCenterLocation) < distanceThreshold) {
			do interactWithInformationCenter;
		}
	}
   
   /*
    * Interact with the information center to get the next decision.
    * It could be to get the coordinates and go to the store; it could also be to wait until a store is restocked.
    */ 
	action interactWithInformationCenter{
//		write "The person go to the InformationCenter";
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
	int foodSupply <- 1;
	int drinkSupply <- 1;
	// Time required for stock
	int foodRestockTimeSlot <- 0;
	int drinkRestockTimeSlot <- 0;
	
	init {
		foodSupply <- 1;
		drinkSupply <- 1;
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
			// There is no supply, update guest memory, prompt refresh failed.
			list<point> sameLocation <- guest.recentStoreLocation where (each distance_to location < distanceThreshold);
			if (length(sameLocation) = 0) {
				do addInformationToGuestMemory(guest);
			} else {
				do modifyGuestMemory(guest);
			}
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
		string storeType <- getCurrentStoreType();
		list<point> sameLocation <- guest.recentStoreLocation where (each distance_to location < distanceThreshold);
		if (length(sameLocation) = 0) {
			do addInformationToGuestMemory(guest);
		} else {
			do modifyGuestMemory(guest);
		}
		guest.targetStoreLocation <- nil;
		return guest.isHungry or guest.isThirsty;
	}
	
	// Challenge 1: Add current store information to guest memory.
	action addInformationToGuestMemory(Guest guest){
		string storeType <- getCurrentStoreType();
		guest.recentStoreLocation <- guest.recentStoreLocation + [location];
		guest.recentStoreType <- guest.recentStoreType + [storeType];
		if (length(guest.recentStoreLocation) > 2) {
			remove from:guest.recentStoreLocation index:0;
			remove from:guest.recentStoreType index:0;
		}
	}
	
	// Challenge 1: Modify the current store information in the customer's memory.
	action modifyGuestMemory(Guest guest){
		string storeType <- getCurrentStoreType();
		int ind <- -1;
		loop i from: 0 to: length(guest.recentStoreLocation) - 1{
			if (guest.recentStoreLocation[i] distance_to location < distanceThreshold){
				ind <- i;
				break;
			}
		}
		if (ind != -1){
			guest.recentStoreType[ind] <- storeType;
		}
	}
	
	string getCurrentStoreType{
		if (foodSupply > 0 and drinkSupply > 0) {
			return "both";
		} else if (foodSupply > 0) {
			return "food";
		} else if (drinkSupply > 0) {
			return "drink";
		} else {
			return "none";
		}
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
        
     point getLocationByStatus(Guest per, string type){
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
		Store closestStore <- potentialStores closest_to(per.location);
   	 	return closestStore.location;
   	 }
}

experiment festivalSimulation type: gui{
	output{
		display festivalDisplay{
			species Guest aspect:base;
			species Store aspect:base;
			species InformationCenter aspect: base;
		}
	}
}