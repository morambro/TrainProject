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
with Ticket;use Ticket;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings;
with Ada.Strings.Hash;
with Ada.Exceptions;
with Ada.Containers;use Ada.Containers;
with Ada.Containers.Ordered_Maps;
with Ada.Containers.Vectors;

-- #
-- # Package representing the Regional Ticket Office, to be asked for Ticket Creation.
-- #
package Regional_Ticket_Office is

	No_Route_For_Destination : exception;

	-- #
	-- # Procedure used to perform Ticket_Office initialization.
	-- #
	procedure Init(
		File_Name	: in 	String);


	type Create_Request_Result is record
 		The_Ticket 				: Ticket_Type_Ref := null;
 		Must_Be_Validated	: Boolean := False;
    end record;

	-- #
	-- # Creates and returns a Ticket_Type object, which represents a Ticket to
	-- # go from [From] to [To].
	-- #
	function Create_Ticket(
		From	: in 	String;
		To		: in 	String) return Create_Request_Result;


	-- #
	-- # Procedure used to ask for a ticket to be created. It First Creates a Ticket, and then
	-- # if needed asks Central Ticket Office to Validate it.
	-- #
	procedure Get_Ticket (
		Traveler_Index 	: in 	Positive;
		From			: in 	String;
		To				: in 	String);

private

	type Destinations is array (Positive range <>) of Natural;

	type Destinations_Ref is access all Destinations;

	package String_Array_Maps is new Ada.Containers.Indefinite_Hashed_Maps(
		Key_Type 		=> String,
		Element_Type 	=> Destinations_Ref,
		Hash			=> Ada.Strings.Hash,
		Equivalent_Keys => "="
	);

	type String_Array_Map_Ref is access all String_Array_Maps.Map;

	package Shortest_Path_Maps is new Ada.Containers.Indefinite_Hashed_Maps(
		Key_Type 		=> String,
		Element_Type 	=> String_Array_Map_Ref,
		Hash			=> Ada.Strings.Hash,
		Equivalent_Keys => "="
	);

	-- #
	-- # Initializes [Paths] hash-map with the content of the given file.
	-- #
	procedure Init_Path_Map(
		File_Name	: in 	String);


	-- # Table of couples (String,String_Array_Map_Ref), containing for each Station, the shortest path
	-- # from this Station to each other stations.
	Paths : Shortest_Path_Maps.Map;

--  	-- # A Map containing for each Route the list of Stages for the current Node
--  	-- # with the number of Free Sits per Stage.
--  	Booking_Routes_Map : Booking_Routes.Map;

end Regional_Ticket_Office;