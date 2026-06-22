# Digital Safe Lock

This project contains the Verilog design and testbench for a digital safe lock.

## Prerequisites
- [Icarus Verilog (iverilog)](http://iverilog.icarus.com/) for compilation and simulation.
- [GTKWave](https://gtkwave.sourceforge.net/) for viewing waveforms (optional).

## How to Run the Simulation

1. **Open your terminal or PowerShell** and navigate to the project directory:
   ```powershell
   cd d:\ndmoney4porche\projects\uni\digital_safe_lock
   ```

2. **Compile the design and testbench files**
   Run the following `iverilog` command to compile all the source code (`design/*.v`) and the testbench (`tb/*.v`) into a simulation executable named `sim.vvp`:
   ```powershell
   iverilog -o sim.vvp design/*.v tb/*.v
   ```
   *(Alternatively, you can list out all files explicitly if you prefer).*

3. **Run the simulation**
   Use `vvp` to execute the generated `sim.vvp` file:
   ```powershell
   vvp sim.vvp
   ```
   You should see the simulation results outputted to your console:
   ```text
   ========================================
      DIGITAL SAFE LOCK - TESTBENCH START  
   ========================================

   [Test 1] Unlock with default password (00)
   Pass: Test 1 (LEDG=1, LEDR=0)

   [Test 2] Change password to A5
   Password changed to A5.

   Locking the safe...

   [Test 3] Try unlocking with WRONG password (11)
   Pass: Test 3 (LEDG=0, LEDR=1)

   [Test 4] Unlock with NEW password (A5)
   Pass: Test 4 (LEDG=1, LEDR=0)

   Locking the safe...

   [Test 5] Spam wrong password multiple times
   Pass: Test 51 (LEDG=0, LEDR=1)
   Pass: Test 52 (LEDG=0, LEDR=1)

   [Test 6] Unlock again with correct password (A5)
   Pass: Test 6 (LEDG=1, LEDR=0)
   ========================================
             SIMULATION COMPLETE           
   ========================================
   ```

## Viewing Waveforms (Optional)
The testbench is already configured to automatically generate a `waveform.vcd` file during the simulation.

To view the signal transitions:
1. Ensure you have successfully run the `vvp sim.vvp` command.
2. Open the generated waveform file in GTKWave using the command:
   ```powershell
   gtkwave waveform.vcd
   ```
