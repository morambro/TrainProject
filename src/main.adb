--==============================================================================
-- File:
--	main.adb
-- Author:
--	Moreno Ambrosin
--  	Mat.  : 1035635
-- Date:
-- 	09/02/2013
--==============================================================================

with Environment;use Environment;
with All_Trains;
with Task_Pool;

procedure Main is

	-- Reference type must be in the same scope as the type Access
	--
	-- type Any_Refer is access all Operation_Interface'Class;
	--
	-- Prova : Any_Refer := Op_Red1'Access;

	-- Item : Any_Operation;

	--Exec : Executor;
	
begin
	
	--Put_Line("Passenger Name = "& P.GetName);
	--Put_Line("Passenger Surname = "& P.GetSurname);
	--Put_Line("Passenger ID = "& Integer'Image(P.GetID));
	
	--for I in 1 .. Operations'Length loop
		
		--Task_Pool.Execute(Operations(I));
		
	--end loop;
	

	--T1.Initialize(TD1);
	--T2.Initialize(TD2);
	--T3.Initialize(TD3);
	--T4.Initialize(TD4);
	
	for I in 1 .. Passenger1_Operations'Length loop
		
		Task_Pool.Execute(Passenger1_Operations(I));
		
	end loop;
	
end Main;
