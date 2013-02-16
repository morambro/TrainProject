--==============================================================================
-- File:
--	passenger.ads
-- Created by:
--		Moreno Ambrosin
--  	Mat.  : 1035635
-- Date:
-- 	13/02/2013
--==============================================================================

with Ada.Strings.Unbounded;
with Generic_Operation_Interface;use Generic_Operation_Interface;

package Passenger is
	
	package Unbounded_Strings renames Ada.Strings.Unbounded;
	
	type Passenger_Operations is Array(Positive range <>) of Any_Operation;
	
	-- Passenger type declaration
	type Passenger_Type is record
		ID 			: Integer;
		Name 		: Unbounded_Strings.Unbounded_String;
		Surname 	: Unbounded_Strings.Unbounded_String;
	end record;

	type Passenger_Manager(Op : access Passenger_Operations) is record
		Passenger 		: Passenger_Type;
		Operations 		: access Passenger_Operations;
		Next_Operation 	: Positive := 1;
		-- It will contain
		Destination 	: Positive := 1;
	end record;	
	
end Passenger;
