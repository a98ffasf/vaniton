pragma Ada_2012;

with Ada.Containers; use Ada.Containers;
with Ada.Text_IO;
with GNAT.Regexp;

with Addresses;
with Cryptography;

package body Workers is
   protected body Control is
      procedure Signal_Stop is
      begin
         Flag_Stop := True;
      end Signal_Stop;

      function Stop return Boolean is (Flag_Stop);
   end Control;

   task body Worker is
      use GNAT.Regexp;

      Current    : Work_Unit;
      Kind       : Wallets.Wallet_Kind;
      Expression : Regexp;
   begin
      accept Start
        (Wallet_Kind    : Wallets.Wallet_Kind; Pattern : String;
         Case_Sensitive : Boolean)
      do
         Kind       := Wallet_Kind;
         Expression := Compile (Pattern, False, Case_Sensitive);
      end Start;

      while not Control.Stop loop
         Current.Phrase := Generate;
         declare
            use Cryptography;

            KP : constant Key_Pair := To_Key_Pair (Current.Phrase);
         begin
            Current.Address :=
              Addresses.To_String
                (Wallets.Get_Wallet_Address
                   (Public_Key => KP.Public_Key, Kind => Kind));
         end;

         if Match (Current.Address, Expression) then
            Work_Queue.Enqueue (Current);
         end if;
      end loop;
   end Worker;

   task body Writer is
      use Ada.Text_IO;

      Current : Work_Unit;

      type File_Access_Array is array (Positive range <>) of File_Access;
      Outputs_Array : access File_Access_Array;

      Output_File : aliased File_Type;
   begin
      accept Start (File_Name : String := "") do
         if File_Name = "" then
            Outputs_Array         := new File_Access_Array (1 .. 1);
            Outputs_Array.all (1) := Standard_Output;
         else
            Create (Output_File, Append_File, File_Name);

            Outputs_Array         := new File_Access_Array (1 .. 2);
            Outputs_Array.all (1) := Standard_Output;
            Outputs_Array.all (2) := Output_File'Unchecked_Access;
         end if;
      end Start;

      while (not Control.Stop) or else (Work_Queue.Current_Use /= 0) loop
         Work_Queue.Dequeue (Current);

         for File of Outputs_Array.all loop
            Put_Line
              (File.all, Current.Address & "|" & To_String (Current.Phrase));
         end loop;
      end loop;
   end Writer;

end Workers;
