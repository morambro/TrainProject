----------------------------------------------------------------------------------
--  Copyright 2013                                								--
--  Moreno Ambrosin                         									--
--  Railway_Simulation 1.0                                       				--
--  Concurrent and Distributed Systems class project  							--
--  Master Degree in Computer Science                 							--
--  Academic year 2012/2013                              						--
--  Dept. of Pure and Applied Mathematics             							--
--  University of Padua, Italy                        							--
--                                                    							--
--  This file is part of Railway_Simulation project.							--
--																				--
--  Railway_Simulation is free software: you can redistribute it and/or modify	--
--  it under the terms of the GNU General Public License as published by		--
--  the Free Software Foundation, either version 3 of the License, or			--
--  (at your option) any later version.											--
--																				--
--  Railway_Simulation is distributed in the hope that it will be useful,		--
--  but WITHOUT ANY WARRANTY; without even the implied warranty of				--
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the				--
--  GNU General Public License for more details.								--
--																				--
--  You should have received a copy of the GNU General Public License			--
--  along with Railway_Simulation.  If not, see <http://www.gnu.org/licenses/>. --
----------------------------------------------------------------------------------

with Ada.Text_IO;use Ada.Text_IO;
with Logger;
with Environment;
with Route;use Route;
with Routes;
with Trains;
with Ada.Exceptions;
with Ticket;
with Remote_Station_Interface;
with Regional_Ticket_Office;
with Central_Controller_Interface;

with Ada.Calendar;
with Ada.Calendar.Formatting;use Ada.Calendar.Formatting;
with Ada.Calendar.Time_Zones;use Ada.Calendar.Time_Zones;

package body Gateway_Station is

	-- ###################################################################################################
	-- ######################### Definition of the inherited abstract methods ############################
	-- ###################################################################################################

	function Get_Name(
		This 				: in out 	Gateway_Station_Type) return String is
	begin
		return To_String(This.Name);
    end Get_Name;

	procedure Enter(
		This 				: in out	Gateway_Station_Type;
		Descriptor_Index	: in		Positive;
		Platform_Index		: in		Positive;
		Segment_ID			: in 		Positive;
		Action				: in 		Route.Action)
	is
	begin

		-- # First, pass the Access Controller, to maintain the same order
		-- # as the exit order from the Segment <Segment_ID>
		This.Segments_Map_Order.Element(Segment_ID).Enter(
			Train_Index	=> Descriptor_Index);

		-- # Add The Train to Platform internal queue.
		This.Platforms(Platform_Index).Add_Train(Descriptor_Index);

		-- # Now we can Free the Access controller, to let other Tasks to be awaked.
		This.Segments_Map_Order.Element(Segment_ID).Free;

		-- # Once the task passed the Access controller, it occupies the Platform and,
		-- # if needed, performs Alighting of Passengers.
		This.Platforms(Platform_Index).Enter(
			Train_Descriptor_Index 	=> Descriptor_Index,
			Action					=> Action);

		-- # Tell the Notice Panel to display the Train gained access
		This.Panel.Set_Train_Accessed_Platform(
			Train_ID	=> Trains.Trains(Descriptor_Index).ID,
			Platform 	=> Platform_Index);

		-- # Notify the Entrance to Central Ticket Office
		declare
			-- # Get the Current Run index
			Current_Run 	: Positive :=
				Environment.Route_Time_Table(Trains.Trains(Descriptor_Index).Route_Index).Current_Run;

			-- # Get the index of the next time to leave the station
			Current_Run_Cursor	: Positive :=
				Environment.Route_Time_Table(Trains.Trains(Descriptor_Index).Route_Index).Current_Run_Cursor;
			-- # Time to wait before leaving
			Time_To_Wait : Ada.Calendar.Time := Environment.Route_Time_Table(Trains.Trains(Descriptor_Index).Route_Index).Table
				(Current_Run)(Current_Run_Cursor);

			Train_Delay : Duration := Ada.Calendar."-"(Ada.Calendar.Clock, Time_To_Wait);
		begin

			-- # At this point the Task Train has access to the platform,
			-- # So notify the Central Controller.
			Central_Controller_Interface.Set_Train_Arrived_Status(
				Train_ID	=> Trains.Trains(Descriptor_Index).ID,
				Station		=> This.Get_Name,
				Platform	=> Platform_Index,
				Segment		=> Segment_ID,
				-- # Time at witch the Train will leave the Platform.
				Time 		=> Ada.Calendar.Formatting.Image(
								Date					=> Time_To_Wait,
								Include_Time_Fraction 	=> False,
								-- # We are 2 hours later that UTC Time Zone.
								Time_Zone				=> 2*60),
				-- # Duration rounded to Integer, representing seconds
				-- # of delay.
				Train_Delay	=> Integer(Train_Delay));
		end;

		-- # If we have to cross to other region, we are positioned a stage before the first stage on the next region.
		-- # So, let's check for Trains.Trains(Descriptor_Index).Next_Stage + 1!
		if 	Trains.Trains(Descriptor_Index).Next_Stage + 1 <= Routes.All_Routes(Trains.Trains(Descriptor_Index).Route_Index)'Length then
			declare
				-- # Retrieve Next Station index
				Next_Station_Index 	: Positive 	:=
					Routes.All_Routes(Trains.Trains(Descriptor_Index).Route_Index)(Trains.Trains(Descriptor_Index).Next_Stage + 1).Start_Station;
				-- # Retrieve the Node_Name
				Next_Station_Node	: String 	:= To_String(
					Routes.All_Routes(Trains.Trains(Descriptor_Index).Route_Index)(Trains.Trains(Descriptor_Index).Next_Stage + 1).Node_Name);

			begin
			  	if Next_Station_Node /= Environment.Get_Node_Name then
					-- # Send train with descriptor Train_D to the next Station, if defined and on another node, and stop current Train Execution

					-- # Go to the next stage, to let the train start to the right position on the next region
					Trains.Trains(Descriptor_Index).Next_Stage := Trains.Trains(Descriptor_Index).Next_Stage + 1;

					Remote_Station_Interface.Send_Train(
						Train_Descriptor_Index		=>	Descriptor_Index,
						Station 					=> 	Next_Station_Index,
						-- # The platform index will be the same!!
						Platform					=>	Platform_Index,
						Next_Node_Name				=>	Next_Station_Node);
				else
					-- # Tell the Notice Panel to display the Train gained access
					This.Panel.Set_Train_Accessed_Platform(
						Train_ID	=> Trains.Trains(Descriptor_Index).ID,
						Platform 	=> Platform_Index);

					-- # TO SLOW DOWN SIMULATION!
					if (Action = Route.ENTER) then
						delay 2.5;
					else
						delay 1.0;
					end if;
				end if;
			end;
		end if;

	end Enter;


	procedure Leave(
		This 				: in out	Gateway_Station_Type;
		Descriptor_Index	: in		Positive;
		Platform_Index		: in		Positive;
		Action				: in 		Route.Action)
	is

	begin
		-- # If the next Stage is in the same Region, proceed with a local Leave operation
		This.Platforms(Platform_Index).Leave(
			Train_Descriptor_Index 	=> Descriptor_Index,
			Action					=> Action);

		-- # Notify the Notice Panel that the Train Left the Platform
		This.Panel.Set_Train_Left_Platform(
			Train_ID 	=> Trains.Trains(Descriptor_Index).ID,
			PLatform	=> Platform_Index);

		if Trains.Trains(Descriptor_Index).Next_Stage - 1 > 0 then
			declare
				-- # Retrieve previous Station index
				Previous_Station_Index 	: Positive 	:=
					Routes.All_Routes(Trains.Trains(Descriptor_Index).Route_Index)(Trains.Trains(Descriptor_Index).Next_Stage - 1).Next_Station;
				-- # Retrieve previous Node
				Previous_Station_Node	: String 	:= To_String(
					Routes.All_Routes(Trains.Trains(Descriptor_Index).Route_Index)(Trains.Trains(Descriptor_Index).Next_Stage - 1).Node_Name);

			begin
				if Previous_Station_Node /= Environment.Get_Node_Name then
					-- # The train was sent by remote Region. So notify it left the Platform!
					Remote_Station_Interface.Train_Left_Message(
						Train_Descriptor_Index		=>	Descriptor_Index,
						Station 					=> 	Previous_Station_Index,
						-- # The platform index were the same!!
						Platform					=>	Platform_Index,
						Node_Name 					=>	Previous_Station_Node);
				end if;
			end;
		end if;

	end Leave;


	overriding procedure Add_Train(
		This				: in out	Gateway_Station_Type;
		Train_ID			: in 		Positive;
		Segment_ID			: in 		Positive) is
	begin
		if not This.Segments_Map_Order.Contains(Segment_ID) then
			Logger.Log(
				Sender 	=> "Regional_Station",
				Message => "Created List for Segment " & Integer'Image(Segment_ID),
				L 		=> Logger.DEBUG
			);
			declare
				-- # Create a new Access Controller for the Segment.
				R : Access_Controller_Ref := new Access_Controller(Segment_ID);
			begin
				This.Segments_Map_Order.Insert(
					Key 		=> Segment_ID,
					New_Item 	=> R);
			end;
		end if;
		Logger.Log(
			Sender 	=> "Regional_Station",
			Message => "Adding Train " & Integer'Image(Train_ID),
			L 		=> Logger.DEBUG);
		This.Segments_Map_Order.Element(Segment_ID).Add_Train(Trains.Trains(Train_ID).ID);

		-- # Notify the Panel that the Train is arriving
		This.Panel.Set_Train_Arriving(
			Train_ID 	=> Trains.Trains(Train_ID).ID,
			PLatform 	=> Routes.All_Routes(Trains.Trains(Train_ID).Route_Index)(Trains.Trains(Train_ID).Next_Stage).Platform_Index);


    end Add_Train;


	-- #
	-- # Procedure called by a Traveler to enqueue at a given Platform
	-- # waiting for a specific Train
	-- #
	procedure Wait_For_Train_To_Go(
			This 				: in out	Gateway_Station_Type;
			Outgoing_Traveler 	: in		Positive;
			Train_ID 			: in		Positive;
			Platform_Index		: in		Positive)
	is
		Next_Stage_Region : Unbounded_String :=
			Environment.Travelers(Outgoing_Traveler).The_Ticket.Stages(
				Environment.Travelers(Outgoing_Traveler).The_Ticket.Next_Stage).Region;
	begin

		Put_Line("NEXT REGION = " & To_String(Next_Stage_Region));

		-- # Check if the Next Step is in the Current Region or not.
		if Next_Stage_Region /= Environment.Get_Node_Name then

			declare
				Next_Station_Index : Positive := This.Destinations.Element(To_String(Next_Stage_Region));
			begin
				-- # If the Next Region is different from the current one, let the
				-- # traveler wait to leave on the other side of the Gateway Station.
				Remote_Station_Interface.Wait_For_Train_To_Go (
					Traveler_Index	=> Outgoing_Traveler,
					Train_ID 		=> Train_ID,
					Station 		=> Next_Station_Index,
					Platform 		=> Platform_Index,
					Node_Name		=> To_String(Next_Stage_Region));
			end;

		else
			This.Platforms(Platform_Index).Add_Outgoing_Traveler(Outgoing_Traveler);

			Logger.Log(
				Sender 	=> "Station " & Unbounded_Strings.To_String(This.Name) & " Platform" & Integer'Image(Platform_Index),
				Message => "Traveler " & Traveler.Get_Name(Environment.Travelers(Outgoing_Traveler)) & " waits to GO",
				L		=> Logger.NOTICE);

		end if;
	end Wait_For_Train_To_Go;



	overriding procedure Wait_For_Train_To_Arrive(
			This 				: in out	Gateway_Station_Type;
			Incoming_Traveler 	: in		Positive;
			Train_ID 			: in		Positive;
			Platform_Index		: in		Positive)
	is
	begin
		This.Platforms(Platform_Index).Add_Incoming_Traveler(Incoming_Traveler);

		Logger.Log(
			Sender 	=> "Station " & Unbounded_Strings.To_String(This.Name) & " Platform" & Integer'Image(Platform_Index),
			Message => "Traveler " & Traveler.Get_Name(Environment.Travelers(Incoming_Traveler)) & " waits to ARRIVE",
			L		=> Logger.NOTICE);

    end Wait_For_Train_To_Arrive;


	procedure Buy_Ticket(
		This 					: in out 	Gateway_Station_Type;
		Traveler_Index			: in	 	Positive;
		To						: in 	 	String)
	is
	begin
		Regional_Ticket_Office.Get_Ticket(Traveler_Index,This.Get_Name,To);
    end Buy_Ticket;

	procedure Terminate_Platforms(
		This 					: in out	 Gateway_Station_Type) is
	begin
		for I in 1 .. This.Platforms'Length loop
			This.Platforms(I).Terminate_Platform;
		end loop;
    end Terminate_Platforms;


    procedure Occupy_Platform(
			This				: in out 	Gateway_Station_Type;
			Platform_Index		: in 		Positive;
			Train_Index			: in 	 	Positive) is
	begin
		This.Platforms(Platform_Index).Add_Train(Train_Index);
		This.Platforms(Platform_Index).Enter(Train_Index,Route.FREE);
    end Occupy_Platform;


    -- ##############################################################################################

	function New_Gateway_Station(
			Platforms_Number 	: in		Positive;
			Name 				: in 		String;
			Destinations		: access String_Positive_Maps.Map) return Station_Ref
	is
		Station : access Gateway_Station_Type := new Gateway_Station_Type(Platforms_Number);
	begin
		Station.Name := Unbounded_Strings.To_Unbounded_String(Name);
		Station.Panel := new Notice_Panel.Notice_Panel_Entity(new String'(To_String(Station.Name)));
		for I in Positive range 1..Platforms_Number loop
			Station.Platforms(I).Init(Station.Name'Access,Station.Panel,I);
		end loop;
		Station.Destinations := Destinations;
		return Station;
	end;


	overriding procedure Print(This : in Gateway_Station_Type) is
	begin
		Put_Line ("Name : " & Unbounded_Strings.To_String(This.Name));
		Put_Line ("Platform Number : " & Integer'Image(This.Platforms_Number));
    end Print;


    overriding procedure Finalize (This: in out Gateway_Station_Type) is
    begin
    	Logger.Log(
    		Sender 	=> "Gateway_Station",
    		Message => "Finalize Station " & Unbounded_Strings.To_String(This.Name),
    		L 		=> Logger.INFO);
    end Finalize;

-- ########################################### JSON - Gateway Station ##########################################

	function Load_Destinations(J_Array : in JSON_Array) return access String_Positive_Maps.Map is
		Array_Length : constant Natural := Length (J_Array);
		Map_To_Return : access String_Positive_Maps.Map := new String_Positive_Maps.Map;
	begin
		for I in 1 .. Array_Length loop
			Map_To_Return.Insert(
				Get(Arr => J_Array, Index => I).Get("region"),
				Get(Arr => J_Array, Index => I).Get("station"));
		end loop;

		return Map_To_Return;
	end Load_Destinations;

	function Get_Gateway_Station(Json_Station : Json_Value) return Station_Ref
	is
		Platforms_Number 	: Positive := Json_Station.Get("platform_number");
		Name 				: String := Json_Station.Get("name");
		New_Station 		: Station_Ref := New_Gateway_Station(
			Platforms_Number,
			Name,
			Load_Destinations(Json_Station.Get("links")));
	begin
		return New_Station;
	end Get_Gateway_Station;


end Gateway_Station;
