/**
* Name: BDI2
* Based on the internal empty template. 
* Author: JKX & Dearcfy
* Tags: 2个场所(酒店和派对) 50个客人 5种类型的人(regular_people、enjoy_party、cool_guy、exhaust_guy、loyal_guy) 每个客人有三种不同的traits(酒精接受度、慷慨值、内/外向) 有1个套规则定义与其他人交互方式
*/


model BDI2

/* Insert your model definition here */

global{
	int numberOfPeople <- 50;             // 定义游客数量
	predicate party_desire <- new_predicate("party_desire");          // 想去派对的愿望
	predicate hotel_desire <- new_predicate("hotel_desire");             // 想回酒店的游客
	predicate wander_desire <- new_predicate("wander_desire");         // 想闲逛的愿望
	
	string party_Location <- "party_Location";
	string hotel_Location <- "hotel_Location";
	
	// 可以删除考虑
	predicate PL <- new_predicate(party_Location);                // 获取派对的位置
	predicate HL <- new_predicate(hotel_Location);                // 获取酒店的位置
	
	predicate party_is_target <- new_predicate("party_is_target");  // 将派对设置为目标地址的子意图
	predicate hotel_is_target <- new_predicate("hotel_is_target");      // 将酒店设为目标的子意图
	
	map<string,int> happiness_level;                           // 幸福指数
	int agree_sum <- 0;
	int refuse_sum <- 0;
	
	list<string> personality <- ['Extroversion', 'Introversion'];     // 代理的性格
	int conservation_sum <- 0;
	
	init{
		create guest number: numberOfPeople;
		create party number: 1;
		create hotel number: 1;
	}
}

species guest skills:[moving, fipa] control: simple_bdi{
	string agent_tag_personality <- personality[rnd(0,1)];                 // 为代理分配性格
	bool alochol <- flip(0.5);                                              // 酒精接受度
	bool generous <- flip(0.5);                                             // 慷慨值
	
	int temple_for_type <- rnd(0,100);
	string agent_type <- nil;
	point target <- nil;                       // 存放目标位置
	
	int desire_completion <- 0;       // 定时刷新欲望
	list<guest> All_guest;         // 存放所有游客的列表
	list<string> guest_Name;       // 存放游客的名字
	string current_desire <- nil;  // 存放当前的愿望
	guest asked_last_time <- nil;  // 存放上一次交互过的人
	int happyLevel;        // 当前的幸福值
	
	init{             // 开局分配不同类型的顾客
		if(temple_for_type < 35){
			agent_type <- 'regular_people';
		}else if(temple_for_type > 35 and temple_for_type <= 48){
			agent_type <- 'enjoy_party';
		}else if(temple_for_type > 48 and temple_for_type <= 69){
			agent_type <- 'cool_guy';
		}else if(temple_for_type > 69 and temple_for_type < 82){
			agent_type <- 'exhaust_guy';
		}else{
			agent_type <- 'loyal_guy';
		}
		
		All_guest <- list(guest);  // 将所有游客存放进去
		guest_Name <- All_guest collect each.name;  // 存放所有游客的名字
		loop i from: 0 to: length(guest_Name) - 1{
			add guest_Name[i] :: 0 to: happiness_level;          // 给所有游客的幸福指数一个初始值
		}
	}
	
	perceive target: party{   // 感知派对的位置
		focus id: party_Location var: location;
	}
	
	perceive target: hotel{       // 感知酒店的位置 
		focus id: hotel_Location var: location;
	}

	plan party intention: party_desire{              // 计划party是为实现party_desire这个意图
		if(target = nil){
			do add_subintention(get_current_intention(), party_is_target, true);   // 将找到party的位置为当前意图
			do current_intention_on_hold();          // 挂起当前意图
		}else{
			do goto target: target;                  // 向目标移动
			write name +"has intention to go towards party location";
			if(target = location){                   // 到达目标了
				desire_completion <- desire_completion + 1;
				do wander;
				if(desire_completion >= 20){         // 去新的位置
					write name +"thinking of other desire";
					target <- nil;
					desire_completion <- 0;
					current_desire <- nil;
					do remove_intention(party_desire, true);
				}
			}
		}
	}
	plan party_is_target intention: party_is_target instantaneous:true{    // 计划 party_is_target 是为实现 party_is_target 这个意图
	// 从信念中找到相应位置
	list<point> possible_party_locations <- get_beliefs_with_name(party_Location) collect (point(get_predicate(mental_state (each)).values["location_value"]));
	write name +"get a belief for party location";
	target <- (possible_party_locations with_min_of (each distance_to self)).location;
	do remove_intention(party_is_target, true);
	}
	
	plan hotle intention: hotel_desire{
		if(target = nil){
			do add_subintention(get_current_intention(), hotel_is_target, true);
			do current_intention_on_hold();
		}
		else{
			do goto target: target;
			write name +"has intention to go towards hotel location";
			if(location = target){
				desire_completion <- desire_completion + 1;
				do wander;
				if(desire_completion >= 20){
					write name +"thinking of other desire";
					target <- nil;
					desire_completion <- 0;
					current_desire <- nil;
					do remove_intention(hotel_desire, true);
				}
			}
		}
	}	
	plan hotel_is_target intention: hotel_is_target instantaneous:true{
		list<point> possible_hotel_locations <- get_beliefs_with_name(hotel_Location) collect (point(get_predicate(mental_state (each)).values["location_value"]));
		write name +"get a belief for restrunt location";
		target <- (possible_hotel_locations with_min_of (each distance_to self)).location;
		do remove_intention(hotel_is_target, true);
	}	

	plan wander intention: wander_desire {         // 计划完成wander
		float x_wander_min <- (self.location.x - 10 ) < 0 ? 0 : self.location.x - 10;
		float x_wander_max <- (self.location.x + 10 ) > 100 ? 100 : self.location.x + 10;
		float y_wander_min <- (self.location.x - 10 ) < 0 ? 0 : self.location.y - 10;
		float y_wander_max <- (self.location.x + 10 ) > 100 ? 100 : self.location.y + 10;
		do goto target:point(rnd(x_wander_min , x_wander_max), rnd(y_wander_min, y_wander_max));
		write name +"has intention to wander";
		desire_completion <- desire_completion + 1;
		if(desire_completion >= 35){
			write name +"thinking of other desire";
			target <- nil;
			desire_completion <- 0;
			current_desire <- nil;
			do remove_intention(wander_desire, true);
		}
	}

	action get_new_desire{          // 更新desire
		if (current_desire = 'party'){
			write name+"I have a desire to party";
			do add_desire(party_desire);
		}
		if (current_desire = 'hotel'){
			write name+"I have a desire to hotel";
			do add_desire(hotel_desire);
		}
		if (current_desire = 'wander'){
			write name+"I have a desire to wander";
			do add_desire(wander_desire);
		}
	}
	
	reflex get_a_desire when: current_desire = nil{       // 获得不同的desire
		int template <- rnd(0,100);
		switch agent_type{
			match 'regular_people'{
				switch template{
					match_between [0, 33] {current_desire <- 'party';}
					match_between [34, 66] {current_desire <- 'hotel';}
					match_between [67, 100] {current_desire <- 'wander';}
				}
			}
			match 'enjoy_party'{
				switch template{
					match_between [0, 55] {current_desire <- 'party';}
					match_between [56, 77] {current_desire <- 'hotel';}
					match_between [78, 100] {current_desire <- 'wander';}
				}
			}
			match 'cool_guy'{
				switch template{
					match_between [0, 22] {current_desire <- 'party';}
					match_between [23, 43] {current_desire <- 'hotel';}
					match_between [44, 100] {current_desire <- 'wander';}
				}
			}
			match 'exhaust_guy'{
				switch template{
					match_between [0, 10] {current_desire <- 'party';}
					match_between [11, 66] {current_desire <- 'hotel';}
					match_between [67, 100] {current_desire <- 'wander';}
				}
			}
			match 'loyal_guy'{switch template{
					match_between [0, 33] {current_desire <- 'party';}
					match_between [33, 66] {current_desire <- 'hotel';}
					match_between [66, 100] {current_desire <- 'wander';}
				}
			}
			default {}
		}
		do get_new_desire;
	}
	reflex guest_ask when: !(empty(guest at_distance 5)){   // 向附近游客发送信息
		switch agent_type{
			match 'regular_people'{        // 
				bool ask_willing <- flip(0.5); // 0.5的意愿决定去社交
 	    		if(ask_willing){
					list<guest> nearby_guest <- guest at_distance 5;  // 找到范围内的游客
					guest Choosen <- nearby_guest[0 , rnd(length(nearby_guest) - 1)]; // 随机选取一个范围内的游客
					if(asked_last_time != Choosen){
						// 发送自身的一些相关信息
						do start_conversation to: [Choosen] protocol: 'fipa-contract-net' performative: 'inform' contents: [name, agent_type, agent_tag_personality, alochol, generous];
					}
					asked_last_time <- Choosen;
				}else{
					asked_last_time <- guest at_distance 5 at 0;
				}
			}
			match 'enjoy_party'{
				bool ask_willing <- flip(0.8);  // 0.8 的意愿决定去社交
				if(ask_willing) {
					list<guest> nearby_guest <- guest at_distance 5;  // 找到范围内的游客
					guest Choosen <- nearby_guest[0 , rnd(length(nearby_guest) - 1)]; // 随机选取一个范围内的游客
					if(asked_last_time != Choosen){
						// 发送自身的一些相关信息
						do start_conversation to: [Choosen] protocol: 'fipa-contract-net' performative: 'inform' contents: [name, agent_type, agent_tag_personality, alochol, generous];
					}
					asked_last_time <- Choosen;
				}else{
					asked_last_time <- guest at_distance 5 at 0;
				}
			}
			match 'cool_guy'{
				bool ask_willing <- flip(0.3);  // 0.3 的意愿决定去社交
				if(ask_willing){
					list<guest> nearby_guest <- guest at_distance 5;  // 找到范围内的游客
					guest Choosen <- nearby_guest[0 , rnd(length(nearby_guest) - 1)]; // 随机选取一个范围内的游客
					if(asked_last_time != Choosen){
						// 发送自身的一些相关信息
						do start_conversation to: [Choosen] protocol: 'fipa-contract-net' performative: 'inform' contents: [name, agent_type, agent_tag_personality, alochol, generous];
					}
					asked_last_time <- Choosen;
				}else{
					asked_last_time <- guest at_distance 5 at 0;
				}
			}
			match 'exhaust_guy'{
				bool ask_willing <- flip(0.4);   // 0.4 的意愿决定去社交
				if(ask_willing){
					list<guest> nearby_guest <- guest at_distance 5;  // 找到范围内的游客
					guest Choosen <- nearby_guest[0 , rnd(length(nearby_guest) - 1)]; // 随机选取一个范围内的游客
					if(asked_last_time != Choosen){
						// 发送自身的一些相关信息
						do start_conversation to: [Choosen] protocol: 'fipa-contract-net' performative: 'inform' contents: [name, agent_type, agent_tag_personality, alochol, generous];
					}
					asked_last_time <- Choosen;
				}else{
					asked_last_time <- guest at_distance 5 at 0;
				}
			}
			match 'loyal_guy'{
				bool ask_willing <- flip(0.5);  // 0.5 的意愿决定去社交
				if(ask_willing){
					list<guest> nearby_guest <- guest at_distance 5;  // 找到范围内的游客
					guest Choosen <- nearby_guest[0 , rnd(length(nearby_guest) - 1)]; // 随机选取一个范围内的游客
					if(asked_last_time != Choosen){
						// 发送自身的一些相关信息
						do start_conversation to: [Choosen] protocol: 'fipa-contract-net' performative: 'inform' contents: [name, agent_type, agent_tag_personality, alochol, generous];
					}
					asked_last_time <- Choosen;
				}else{
					asked_last_time <- guest at_distance 5 at 0;
				}
			}
		}
	}
	
	// 消息结构为 [name, agent_type, agent_tag_personality, alochol, generous]
	reflex guest_answer when: !empty(informs){
		point party_location;      // 存放派对位置
		point hotel_location;      // 存放酒店位置
		
		ask party{        // 获取派对的位置
			party_location <- location;
		}
		ask hotel{       // 获取酒店的位置
			hotel_location <- location; 
		}
		
		//(regular_people、enjoy_party、cool_guy、exhaust_guy、loyal_guy)  
		// [name, agent_type, agent_tag_personality, alochol, generous]
		switch agent_type{
			match 'regular_people'{
				message inform_content <- informs[length(informs) - 1];  // 得到对方的特征
				if (self.location distance_to party_location <= 5){     // 当 regular_people 在party
					if(inform_content.contents[2] = 'Extroversion' ){    // 如果对面的人是外向的
						write name+"is a"+agent_type+"partying with "+ inform_content.contents[0]+"whose type is "+ inform_content.contents[1];
						do agree message: inform_content contents: ['Yes lets party'];
						agree_sum <- agree_sum + 1;
						conservation_sum <- conservation_sum + 1;
						if(inform_content.contents[3] = true and inform_content.contents[4] = true){
							happyLevel <- 10;
							write "Let's drink";
							happiness_level[name] <- happiness_level[name]+happyLevel;  // 更新自己的幸福值
							happiness_level[inform_content.contents[0]]<- happiness_level[inform_content.contents[0]] + happyLevel; // 更新对面的幸福值
						}else if(inform_content.contents[2] = 'Introversion'){
							write name+"is a"+agent_type+"doesnt want to party with "+ inform_content.contents[0]+"whose type is "+ inform_content.contents[1];
							do cancel message: inform_content contents: ['No I am not interested'];
							refuse_sum <- refuse_sum + 1;
							happyLevel <- 7;
							happiness_level[name] <- happiness_level[name]+happyLevel;  // 更新自己的幸福值
							happiness_level[inform_content.contents[0]]<- happiness_level[inform_content.contents[0]] + happyLevel; // 更新对面的幸福值
						}
					}
				}
				
				else if(self.location distance_to hotel_location <= 5){       // 如果在hotel遇见
					if(inform_content.contents[1] = 'exhaust_guy'){
						write name+"is a"+agent_type+"doesnt want to interact with "+ inform_content.contents[0]+"whose type is "+ inform_content.contents[1];
						do cancel message: inform_content contents: ['No I am not interested'];
						refuse_sum <- refuse_sum + 1;
						happyLevel <- -7;
						happiness_level[name] <- happiness_level[name]+happyLevel;  // 更新自己的幸福值
						happiness_level[inform_content.contents[0]]<- happiness_level[inform_content.contents[0]] + happyLevel; // 更新对面的幸福值
					}
					else{
						write name+"is a"+agent_type+"interact with "+ inform_content.contents[0]+"whose type is "+ inform_content.contents[1];
						do agree message: inform_content contents: ['Yes lets party'];
						agree_sum <- agree_sum + 1;
						happyLevel <- 5;
						happiness_level[name] <- happiness_level[name]+happyLevel;  // 更新自己的幸福值
						happiness_level[inform_content.contents[0]]<- happiness_level[inform_content.contents[0]] + happyLevel; // 更新对面的幸福值
					}
				}
			}// [name, agent_type, agent_tag_personality, alochol, generous]
			match 'enjoy_party'{
				message inform_content <- informs[length(informs) - 1];  // 得到对方的特征
				if(self.location distance_to party_location <= 5){       // 在派对相遇
					if(inform_content.contents[1] = 'enjoy_party' ){
						write name+"is a"+agent_type+"partying with "+ inform_content.contents[0]+"whose type is "+ inform_content.contents[1];
						do agree message: inform_content contents: ['Yes lets party'];
						agree_sum <- agree_sum + 1;
						conservation_sum <- conservation_sum + 1;
						if(inform_content.contents[2] = 'Extroversion' and inform_content.contents[3] = true){
							happyLevel <- 10;
							write "Let's drink";
							happiness_level[name] <- happiness_level[name]+happyLevel;  // 更新自己的幸福值
							happiness_level[inform_content.contents[0]]<- happiness_level[inform_content.contents[0]] + happyLevel; // 更新对面的幸福值
						}else if(inform_content.contents[3] = false){
							happyLevel <- 5;
							happiness_level[name] <- happiness_level[name]+happyLevel;  // 更新自己的幸福值
							happiness_level[inform_content.contents[0]]<- happiness_level[inform_content.contents[0]] + happyLevel; // 更新对面的幸福值
						}
					}else{
						write name+"is a"+agent_type+"doesnt want to party with "+ inform_content.contents[0]+"whose type is "+ inform_content.contents[1];
						do cancel message: inform_content contents: ['No I am not interested'];
						refuse_sum <- refuse_sum + 1;
						happyLevel <- -7;
						happiness_level[name] <- happiness_level[name]+happyLevel;  // 更新自己的幸福值
						happiness_level[inform_content.contents[0]]<- happiness_level[inform_content.contents[0]] + happyLevel; // 更新对面的幸福值
					}
				}
				
				else if(self.location distance_to hotel_location <= 5){   // 在酒店相遇
					if(inform_content.contents[1] = 'exhaust_guy'){
						write name+"is a"+agent_type+"doesnt want to party with "+ inform_content.contents[0]+"whose type is "+ inform_content.contents[1];
						do cancel message: inform_content contents: ['No I am not interested'];
						refuse_sum <- refuse_sum + 1;
						happyLevel <- -5;
						happiness_level[name] <- happiness_level[name]+happyLevel;  // 更新自己的幸福值
						happiness_level[inform_content.contents[0]]<- happiness_level[inform_content.contents[0]] + happyLevel; // 更新对面的幸福值
					}
				}
			}// [name, agent_type, agent_tag_personality, alochol, generous]
			match 'cool_guy'{
				message inform_content <- informs[length(informs) - 1];  // 得到对方的特征
				if(self.location distance_to party_location <= 5){       // 在派对遇见
					write name+"is a"+agent_type+"doesnt want to party with "+ inform_content.contents[0]+"whose type is "+ inform_content.contents[1];
					do cancel message: inform_content contents: ['No I am not interested'];
					refuse_sum <- refuse_sum + 1;
					conservation_sum <- conservation_sum + 1;
					happyLevel <- -4;
					happiness_level[name] <- happiness_level[name]+happyLevel;  // 更新自己的幸福值
					happiness_level[inform_content.contents[0]]<- happiness_level[inform_content.contents[0]] + happyLevel; // 更新对面的幸福值
				}
				else if(self.location distance_to hotel_location <= 5) {   // 在酒店遇见
					if(inform_content.contents[1] = 'cool_guy'){
						happyLevel <- 8;
						write "Let's talk";
						happiness_level[name] <- happiness_level[name]+happyLevel;  // 更新自己的幸福值
						happiness_level[inform_content.contents[0]]<- happiness_level[inform_content.contents[0]] + happyLevel; // 更新对面的幸福值
					}
					else{
						happyLevel <- 4;
						happiness_level[name] <- happiness_level[name]+happyLevel;  // 更新自己的幸福值
						happiness_level[inform_content.contents[0]]<- happiness_level[inform_content.contents[0]] + happyLevel; // 更新对面的幸福值
					}
				}
			}// [name, agent_type, agent_tag_personality, alochol, generous]
			match 'exhaust_guy'{
				message inform_content <- informs[length(informs) - 1];  // 得到对方的特征
				if(self.location distance_to party_location <= 5){       // 在派对遇见
					write name+"is a"+agent_type+"doesnt want to party with "+ inform_content.contents[0]+"whose type is "+ inform_content.contents[1];
					do cancel message: inform_content contents: ['No I am not interested'];
					refuse_sum <- refuse_sum + 1;
					conservation_sum <- conservation_sum + 1;
					happyLevel <- -4;
					happiness_level[name] <- happiness_level[name]+happyLevel;  // 更新自己的幸福值
					happiness_level[inform_content.contents[0]]<- happiness_level[inform_content.contents[0]] + happyLevel; // 更新对面的幸福值
				}
				else if(self.location distance_to hotel_location <= 5) {   // 在酒店遇见
					if(inform_content.contents[1] = 'exhaust_guy'){
						happyLevel <- 10;
						write "Let's talk";
						happiness_level[name] <- happiness_level[name]+happyLevel;  // 更新自己的幸福值
						happiness_level[inform_content.contents[0]]<- happiness_level[inform_content.contents[0]] + happyLevel; // 更新对面的幸福值
					}
					else{
						happyLevel <- -2;
						happiness_level[name] <- happiness_level[name]+happyLevel;  // 更新自己的幸福值
						happiness_level[inform_content.contents[0]]<- happiness_level[inform_content.contents[0]] + happyLevel; // 更新对面的幸福值
					}
				}
			}// [name, agent_type, agent_tag_personality, alochol, generous]
			match 'loyal_guy'{
				message inform_content <- informs[length(informs) - 1];  // 得到对方的特征
				if(self.location distance_to party_location <= 5){       // 在派对遇见
					if(inform_content.contents[1] = 'loyal_guy'){
						write name+"is a"+agent_type+"partying with "+ inform_content.contents[0]+"whose type is "+ inform_content.contents[1];
						do agree message: inform_content contents: ['Yes lets party'];
						agree_sum <- agree_sum + 1;
						conservation_sum <- conservation_sum + 1;
						if(inform_content.contents[3] = true){
							happyLevel <- 8;
							happiness_level[name] <- happiness_level[name]+happyLevel;  // 更新自己的幸福值
							happiness_level[inform_content.contents[0]]<- happiness_level[inform_content.contents[0]] + happyLevel; // 更新对面的幸福值
						}else{
							happyLevel <- 4;
							happiness_level[name] <- happiness_level[name]+happyLevel;  // 更新自己的幸福值
							happiness_level[inform_content.contents[0]]<- happiness_level[inform_content.contents[0]] + happyLevel; // 更新对面的幸福值
						}
					}else if (inform_content.contents[1] = 'cool_guy'){
						write name+"is a"+agent_type+"partying with "+ inform_content.contents[0]+"whose type is "+ inform_content.contents[1];
						do agree message: inform_content contents: ['Yes lets party'];
						agree_sum <- agree_sum + 1;
						conservation_sum <- conservation_sum + 1;
						if(inform_content.contents[3] = true){
							happyLevel <- 5;
							happiness_level[name] <- happiness_level[name]+happyLevel;  // 更新自己的幸福值
							happiness_level[inform_content.contents[0]]<- happiness_level[inform_content.contents[0]] + happyLevel; // 更新对面的幸福值
						}else{
							happyLevel <- -2;
							happiness_level[name] <- happiness_level[name]+happyLevel;  // 更新自己的幸福值
							happiness_level[inform_content.contents[0]]<- happiness_level[inform_content.contents[0]] + happyLevel; // 更新对面的幸福值
						}
					}else if (inform_content.contents[1] = 'exhaust_guy'){
						write name+"is a"+agent_type+"partying with "+ inform_content.contents[0]+"whose type is "+ inform_content.contents[1];
						do agree message: inform_content contents: ['Yes lets party'];
						agree_sum <- agree_sum + 1;
						conservation_sum <- conservation_sum + 1;
						if(inform_content.contents[3] = true){
							happyLevel <- 8;
							happiness_level[name] <- happiness_level[name]+happyLevel;  // 更新自己的幸福值
							happiness_level[inform_content.contents[0]]<- happiness_level[inform_content.contents[0]] + happyLevel; // 更新对面的幸福值
						}else{
							happyLevel <- -3;
							happiness_level[name] <- happiness_level[name]+happyLevel;  // 更新自己的幸福值
							happiness_level[inform_content.contents[0]]<- happiness_level[inform_content.contents[0]] + happyLevel; // 更新对面的幸福值
						}
					}else{
						write name+"is a"+agent_type+"partying with "+ inform_content.contents[0]+"whose type is "+ inform_content.contents[1];
						do agree message: inform_content contents: ['Yes lets party'];
						agree_sum <- agree_sum + 1;
						conservation_sum <- conservation_sum + 1;
						if(inform_content.contents[3] = true){
							happyLevel <- 8;
							happiness_level[name] <- happiness_level[name]+happyLevel;  // 更新自己的幸福值
							happiness_level[inform_content.contents[0]]<- happiness_level[inform_content.contents[0]] + happyLevel; // 更新对面的幸福值
						}else{
							happyLevel <- 4;
							happiness_level[name] <- happiness_level[name]+happyLevel;  // 更新自己的幸福值
							happiness_level[inform_content.contents[0]]<- happiness_level[inform_content.contents[0]] + happyLevel; // 更新对面的幸福值
						}
					}
				}
				else if(self.location distance_to hotel_location <= 5) {   // 在酒店遇见
					if(inform_content.contents[2] = 'loyal_guy'){
						write name+"is a"+agent_type+"interact with "+ inform_content.contents[0]+"whose type is "+ inform_content.contents[1];
						do agree message: inform_content contents: ['Yes lets party'];
						agree_sum <- agree_sum + 1;
						conservation_sum <- conservation_sum + 1;
						if(inform_content.contents[3] = 'Extroversion'){
							happyLevel <- 8;
							happiness_level[name] <- happiness_level[name]+happyLevel;  // 更新自己的幸福值
							happiness_level[inform_content.contents[0]]<- happiness_level[inform_content.contents[0]] + happyLevel; // 更新对面的幸福值
						}else{
							happyLevel <- 4;
							happiness_level[name] <- happiness_level[name]+happyLevel;  // 更新自己的幸福值
							happiness_level[inform_content.contents[0]]<- happiness_level[inform_content.contents[0]] + happyLevel; // 更新对面的幸福值
						}
					}else{
						write name+"is a"+agent_type+"doesnt want to inteact with "+ inform_content.contents[0]+"whose type is "+ inform_content.contents[1];
						do cancel message: inform_content contents: ['No I am not interested'];
						refuse_sum <- refuse_sum + 1;
						conservation_sum <- conservation_sum + 1;
						happyLevel <- -4;
						happiness_level[name] <- happiness_level[name]+happyLevel;  // 更新自己的幸福值
						happiness_level[inform_content.contents[0]]<- happiness_level[inform_content.contents[0]] + happyLevel; // 更新对面的幸福值
					}
				}
			}
		}
		
	}

	rgb get_color{
		if(self.agent_type = 'regular_people'){
			return #white;
		}
		else if(self.agent_type = 'enjoy_party'){
			return #purple;
		}
		else if(self.agent_type = 'cool_guy'){
			return #green;
		}
		else if(self.agent_type = 'exhaust_guy'){
			return #black;
		}
		else{
			return #red;
		}
	} 
	
	aspect base{
		draw sphere(2) color: get_color() ;
	}
}

species party{
	aspect base{
		draw circle(15) color:#blue;
	}
}

species hotel{
	aspect base{
		draw circle(15) color:#gold;
	}
}

experiment my_experiment type: gui{
	output{
		display map_3D type: opengl{
			species party aspect: base;
			species hotel aspect: base;
			species guest aspect: base;
			
		}
		
		display chart1{
			chart "happiness" type: series style: spline {
				data "happiness" value: happiness_level.values;
			}
		}
		display chart2{
			chart "agree" type: series style: spline{
				data "agree" value: agree_sum;			} 
		}
		display chart3{
			chart "refuse" type: series style: spline{
				data "agree" value: refuse_sum;
			}
		}	
	}
}