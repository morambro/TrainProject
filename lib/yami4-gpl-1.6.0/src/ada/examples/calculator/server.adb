with YAMI.Agents;
with YAMI.Incoming_Messages;
with YAMI.Parameters;

with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Text_IO;

procedure Server is

   type Incoming_Message_Handler is
     new YAMI.Incoming_Messages.Message_Handler
     with null record;

   overriding
   procedure Call
     (H : in out Incoming_Message_Handler;
      Message : in out
      YAMI.Incoming_Messages.Incoming_Message'Class) is

     procedure Process
       (Content : in out YAMI.Parameters.Parameters_Collection)
     is
        A : YAMI.Parameters.YAMI_Integer;
        B : YAMI.Parameters.YAMI_Integer;

        Reply_Params :
          YAMI.Parameters.Parameters_Collection :=
          YAMI.Parameters.Make_Parameters;

        use type YAMI.Parameters.YAMI_Integer;
     begin
        --  extract the parameters for calculations

        A := Content.Get_Integer ("a");
        B := Content.Get_Integer ("b");

        --  prepare the answer
        --  with results of four calculations

        Reply_Params.Set_Integer ("sum", A + B);
        Reply_Params.Set_Integer ("difference", A - B);
        Reply_Params.Set_Integer ("product", A * B);

        --  if the ratio cannot be computed,
        --  it is not included in the response
        --  the client will interpret that fact properly
        if B /= 0 then
           Reply_Params.Set_Integer ("ratio", A / B);
        end if;

        Message.Reply (Reply_Params);

        Ada.Text_IO.Put_Line
          ("got message with parameters " &
             YAMI.Parameters.YAMI_Integer'Image (A) &
             " and " &
             YAMI.Parameters.YAMI_Integer'Image (B) &
             ", response has been sent back");
     end Process;

   begin
      Message.Process_Content (Process'Access);
   end Call;

   My_Handler : aliased Incoming_Message_Handler;

begin
   if Ada.Command_Line.Argument_Count /= 1 then
      Ada.Text_IO.Put_Line
        ("expecting one parameter: server destination");
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Failure);
      return;
   end if;

   declare
      Server_Address : constant String :=
        Ada.Command_Line.Argument (1);

      Server_Agent : YAMI.Agents.Agent :=
        YAMI.Agents.Make_Agent;
      Resolved_Server_Address :
        String (1 .. YAMI.Agents.Max_Target_Length);
      Resolved_Server_Address_Last : Natural;
   begin
      Server_Agent.Add_Listener
        (Server_Address,
         Resolved_Server_Address,
         Resolved_Server_Address_Last);

      Ada.Text_IO.Put_Line
        ("The server is listening on " &
           Resolved_Server_Address
           (1 .. Resolved_Server_Address_Last));

      Server_Agent.Register_Object
        ("calculator", My_Handler'Unchecked_Access);

      loop
         delay 10.0;
      end loop;
   end;
exception
   when E : others =>
      Ada.Text_IO.Put_Line
        (Ada.Exceptions.Exception_Message (E));
end Server;
