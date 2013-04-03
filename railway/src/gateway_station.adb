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

package body Gateway_Station is

	-- ------------------------ Definition of the inherited abstract methods ------------------------
	procedure Enter(
			This 				: in		Gateway_Station_Type;
			Descriptor_Index	: in		Positive;
			Platform_Index		: in		Positive;
			Action				: in 		Route.Action) is
	begin

		if Action = Route.ENTER then
			This.Platforms(Platform_Index).Enter(Descriptor_Index);
		end if;
	end Enter;



	procedure Leave(
			This 				: in 		Gateway_Station_Type;
			Descriptor_Index	: in		Positive;
			Platform_Index		: in		Positive) is
	begin
		This.Platforms(Platform_Index).Leave(Descriptor_Index);
	end Leave;

	-- #
	-- # Procedure called by a Traveler to enqueue at a given Platform
	-- # waiting for a specific Train
	-- #
	procedure Wait_For_Train_To_Go(
			This 				: in		Gateway_Station_Type;
			Outgoing_Traveler 	: in		Positive;
			Train_ID 			: in		Positive;
			Platform_Index		: in		Positive) is
	begin
		This.Platforms(Platform_Index).Add_Outgoing_Traveler(Outgoing_Traveler);
		This.Panel.SetStatus(
			"Traveler " & Traveler.Get_Name(Environment.Get_Travelers(Outgoing_Traveler)) &
			" waits by platform " & Integer'Image(Platform_Index) & " station " &
			Unbounded_Strings.To_String(This.Name) & " to GO");
	end Wait_For_Train_To_Go;



	overriding procedure Wait_For_Train_To_Arrive(
			This 				: in		Gateway_Station_Type;
			Incoming_Traveler 	: in		Positive;
			Train_ID 			: in		Positive;
			Platform_Index		: in		Positive) is
	begin
		This.Platforms(Platform_Index).Add_Incoming_Traveler(Incoming_Traveler);
		This.Panel.SetStatus(
			"Traveler " & Traveler.Get_Name(Environment.Get_Travelers(Incoming_Traveler)) &
			" waits by station " & Unbounded_Strings.To_String(This.Name)
			& " at platform " & Integer'Image(Platform_Index) & " to ARRIVE");
    end Wait_For_Train_To_Arrive;


	overriding procedure Add_Train(
			This				: in 		Gateway_Station_Type;
			Train_ID			: in 		Positive;
			Segment_ID			: in 		Positive) is
	begin
		null;
    end Add_Train;



	function New_Gateway_Station(
			Platforms_Number 	: in		Positive;
			Name 				: in 		String) return Station_Ref
	is
		Station : access Gateway_Station_Type := new Gateway_Station_Type(Platforms_Number);
	begin
		Station.Name := Unbounded_Strings.To_Unbounded_String(Name);
		for I in Positive range 1..Platforms_Number loop
			Station.Platforms(I) := new Gateway_Platform.Gateway_Platform_Type(I,Station.Name'Access);
		end loop;
		Station.Panel := new Notice_Panel.Notice_Panel_Entity(1);
		return Station;
	end;


	overriding procedure Print(This : in Gateway_Station_Type) is
	begin
		Put_Line ("Name : " & Unbounded_Strings.To_String(This.Name));
		Put_Line ("Platform Number : " & Integer'Image(This.Platforms_Number));
    end Print;


    function Get_Platform(This : Gateway_Station_Type;P : Natural) return Generic_Platform.Platform_Access is
    begin
    	return This.Platforms(P);
    end Get_Platform;

    overriding procedure Finalize (This: in out Gateway_Station_Type) is
    begin
    	Logger.Log(
    		Sender => "Gateway_Station",
    		Message => "Finalize Station " & Unbounded_Strings.To_String(This.Name),
    		L => Logger.DEBUG);
    end Finalize;

-- ########################################### JSON - Gateway Station ##########################################

	function Get_Regional_Station(Json_Station : Json_Value) return Station_Ref
	is
		Platforms_Number : Positive := Json_Station.Get("platform_number");
		Name : String				:= Json_Station.Get("name");
	begin
		return New_Gateway_Station(Platforms_Number,Name);
	end Get_Regional_Station;


	function Get_Regional_Station_Array(Json_Station : String) return Stations_Array_Ref is
		Json_v  : Json_Value := Get_Json_Value(Json_File_Name => Json_Station);
		J_Array : constant JSON_Array := Json_v.Get(Field => "stations");
		Array_Length : constant Natural := Length (J_Array);
		T : Stations_Array_Ref := new Stations_Array(1 .. Array_Length);
	begin
		for I in 1 .. T'Length loop
			T(I) := Get_Regional_Station(Get(Arr => J_Array, Index => I));
		end loop;

		return T;
    end Get_Regional_Station_Array;


end Gateway_Station;
