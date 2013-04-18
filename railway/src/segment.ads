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

with Train;use Train;
with Gnatcoll.JSON;use Gnatcoll.JSON;
with JSON_Helper;use JSON_Helper;
with Queue;

package Segment is

	package Train_Queue_Package is new Queue(Element => Positive);
	use Train_Queue_Package;

	Bad_Segment_Access_Request_Exception : exception;

	protected type Segment_Type(
		Id 				: Natural;
		Segment_Max_Speed : Positive;
		-- Length expressed in meters
		Segment_Length	: Positive;
		Queue_Dim 		: Positive;
		First_End 		: Positive;
		Second_End 		: Positive;
		Max_Trains		: Positive)

	is

		-- #
		-- # Trains ask to Enter the Segment
		-- #
		entry Leave(Train_D : in Positive);

		-- #
		-- # Trains ask to Enter the Segment
		-- #
		entry Enter(
			To_Add 		: in	 Positive;
			Max_Speed 	: 	 out Positive;
			Leg_Length 	:	 out Positive);

	private

		-- #
		-- # Private Entry used to enqueue trains whose direction are not the same
		-- # as the direction of already running trains.
		-- #
		entry Wait(
			To_Add 		:	in 		Positive;
			Max_Speed 	: 	 	out Positive;
			Leg_Length 	:		out	Positive);

		-- #
		-- # Private Entry used to enqueue trains, to guarantee an exit order.
		-- #
		entry Retry(Train_D : in Positive);

		-- # Tells weather a train is already running or not
		Free 				: Boolean := True;

		-- # Current maximum speed
		Current_Max_Speed 	: Positive := Segment_Max_Speed;

		-- # Current direction. Is set to 0 when the Segment is free
		Current_Direction 	: Natural := 0;

		-- # Queue of all the running trains
		Running_Trains 		: access Limited_Simple_Queue := new Limited_Simple_Queue(Queue_Dim);


		-- # Queue for first End
		First_End_In_Queue 	: Natural := 0;

		-- # Queue for second End
		Second_End_In_Queue : Natural := 0;

		-- # Boolean guard telling if a train can retry to Leave the Segment
		Can_Retry_Leave 	: Boolean := False;

		-- # Boolean guard telling if a train can retry to Enter the Segment
		Can_Retry_Enter 	: Boolean := False;

		-- # Number of exit attempt
		Enter_Retry_Num 	: Natural := 0;

		-- # Number of exit attempt
		Retry_Num 			: Natural := 0;

		-- # Number of trains currently running
		Trains_Number 		: Natural := 0;

		Train_Entered_Per_Direction	: Natural := 0;

	end Segment_Type;

	type Segments_Array is array (Positive range <>) of access Segment_Type;

	------------------------------------ Json -> Segment functions ----------------------
	-- Methods used to load Segment data from a json configuration file

	function Get_Segment_Array(File_Name : String) return access Segments_Array;

	-- #
	-- # A Simple Print procedure, used for debugging purposes
	-- #
	procedure Print(Segment : access Segment_Type);

private

	function Get_Segment(Json_Segment : Json_Value) return access Segment_Type;

	function Get_Segment_Array(Json_v : Json_Value) return access Segments_Array;

end Segment;
