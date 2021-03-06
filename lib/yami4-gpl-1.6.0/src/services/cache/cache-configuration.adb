--  Copyright Maciej Sobczak 2008-2012.
--  This file is part of YAMI4.
--
--  YAMI4 is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.
--
--  YAMI4 is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with YAMI4.  If not, see <http://www.gnu.org/licenses/>.

with IAL.Properties;
with Log;

with Ada.Command_Line;
with Ada.IO_Exceptions;
with Ada.Text_IO;

package body Cache.Configuration is

   Default_Config_File_Name : constant String := "yami4cache.cfg";

   procedure Init (Success : out Boolean) is

      procedure Init_From_File (Config_File_Name : in String) is
      begin
         IAL.Properties.Load_Properties (Config_File_Name);
         Success := True;
      exception
         when Ada.IO_Exceptions.Name_Error =>
            Log.Put
              (Cache.Main, "Cannot read the configuration file: " &
                 Config_File_Name);
      end Init_From_File;

   begin
      Success := False;
      if Ada.Command_Line.Argument_Count /= 0 then
         Init_From_File (Ada.Command_Line.Argument (1));
      else
         Init_From_File (Default_Config_File_Name);
      end if;
   end Init;

   function Listener return String is
   begin
      return IAL.Properties.Get ("listener", "tcp://*:*");
   end Listener;

   function Data_Max_Size return Ada.Streams.Stream_Element_Count is
   begin
      return Ada.Streams.Stream_Element_Count'Value
        (IAL.Properties.Get ("data.max_total_size", "1_000_000"));
   end Data_Max_Size;

   function Data_Eviction_Time return Duration is
   begin
      return Duration'Value (IAL.Properties.Get
                               ("data.eviction_time", "60.0"));
   end Data_Eviction_Time;

   function Data_Eviction_Scan_Period return Duration is
   begin
      return Duration'Value (IAL.Properties.Get
                               ("data.eviction_scan_period", "10.0"));
   end Data_Eviction_Scan_Period;

   function Log_Enabled (Module : in Cache_Module) return Boolean is
   begin
      return Boolean'value
        (IAL.Properties.Get
           ("log." & Cache.Cache_Module'Image (Module), "false"));
   end Log_Enabled;

end Cache.Configuration;
