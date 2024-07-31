# How to use
Exploits exist in both save game and system link forms, please follow the instructions for the exploit method you want to use.

| Game | Network RCE | NTSC | PAL | Other Region | Notes |
| --- | --- | --- | --- | --- | --- |
| Tony Hawk's Pro Skater 3 | ✖ | ✔ | ✖ | N/A | |
| Tony Hawk's Pro Skater 4 | ✔ (NTSC) | ✔ | ✔ | ✔ | |
| Tony Hawk's Underground 1 | ❌ | ❌ | ❌ | ❌ | Game compiled using stack cookies, stack buffer overflow not possible |
| Tony Hawk's Underground 2 | ❌ | ❌ | ❌ | ❌ | Game compiled using stack cookies, stack buffer overflow not possible |
| Tony Hawk's American Wasteland | ✖ | ✔ | ✖ | N/A | |

✔ = Exploit supported and written  
✖ = Exploitation possible but not yet written  
❌ = Exploitation not possible

**Network RCE** = Exploitation using network play (doesn't require game save or memory card)  
**NTSC** = Save game exploit for NTSC region  
**PAL** = Save game exploit for PAL region  
**Other Region** = Save game exploit for other regions

## Save Game Exploit
Save game exploits in the releases download have already been signed. Please use the save game files that match the region of your game.

1. Each save has a placeholder 'default.xbe' file that needs to be replaced with the xbe you want to launch that's signed using the habibi RSA key. See [Xbe Signing](#xbe-signing) for instructions on how to do this. For demonstration purposes you can find the pre-signed "nyan-cat" test xbe in the "TonyHawksProStrcpy-Demo-Executables.zip" file in the releases section.
2. Once your xbe has been signed and copied into the 41560017\3DDF5FA578FC folder you can copy the 41560017 folder to your memory card and then transfer it to your console's HDD. The save must be loaded from your console's HDD, loading it from the memory card is not supported.
3. Launch Tony Hawk's Pro Skater 4 and choose free skate.
4. When you get to the level select screen choose "custom park" and load the "Hack Xbox" game save.
5. After the save is loaded choose "start game" and the exploit should trigger during the loading screen.

## SystemLink Exploit
The system link exploit is currently only supported on the NTSC version of the game. The exploit works by running a patched version of the game on an already modded Xbox that will act as the host of the match. When the client joins the match the host will send the malicious park file to the client and get code execution on their console. Then a file transfer will start and send an arbitrary xbe file to the client that gets saved on their HDD. Once the file transfer completes the client will launch the xbe file, typically a softmod installer xbe, and allow them to softmod their console. 

The exploit files for the host have only been tested on an Xbox console, it's unknown if they work using an emulator or not. The host must patch their game xbe with the "TonyHawkProSkater4-SystemLink-Host-NTSC" patch and load the save game file in the "SystemLink" folder. The other game saves will NOT work with the network exploit.

1. Use [XDelta](https://www.romhacking.net/utilities/598/) to patch a clean NTSC Tony Hawk's Pro Skater 4 xbe with the "TonyHawkProSkater4-SystemLink-Host-NTSC" patch file.
2. Sign your launcher xbe with the habibi RSA key using xbedump found on xbins. See [Xbe Signing](#xbe-signing) for instructions on how to do this. For demonstration purposes you can find the pre-signed "nyan-cat" test xbe in the "TonyHawksProStrcpy-Demo-Executables.zip" file in the releases section.
3. Replace the placeholder 'default.xbe' file in the "SystemLink\41560017\3DDF5FA578FC" folder with your signed launcher xbe.
4. Copy the patched xbe and 41560017 save folder to a modded xbox console. The xbe goes in the game directory (ex: F:\Games\THPS4\) and the save folder goes into E:\UDATA.
5. Run the patched xbe file and select "system link" from the main menu.
6. When you get to the level select screen choose "custom park" and load the "Hack Xbox" game save.
7. Start the network match.
8. Have the client join the host's game (over LAN or tunneling software).
9. When the client joins their console's LED should change colors and they should spawn into the game.
10. While they're playing the host will send the launcher xbe, it will take a minute or two for the transfer to complete.
11. When the transfer completes the client's console will run the launcher xbe.

During the exploit the client's console will change the LED color to indicate what part of the exploit is running:
- LED off: the initial exploit ran and the client has requested the host start the file transfer.
- Orange: the file transfer has started.
- Red: file transfer failed.
- Green: file transfer completed.

# Compiling
To compile the exploit files you'll need XePatcher 2.9 or newer, to compile the host xbe pathes for the system link exploit you'll also need [XboxImageXploder](https://github.com/grimdoomer/XboxImageXploder).

## Save Game Exploits
The game save expoits can be compiled using the following XePatcher command: 
```
XePatcher.exe -p <patch file> -proc x86 -b <save game file>

Ex: XePatcher.exe -p ".\Xbox\Tony Hawk's Pro Skater 4\TonyHawkProSkater4-NTSC.asm" -proc x86 -bin ".\Release\Xbox\Tony Hawk's Pro Skater 4\NTSC\41560017\3DDF5FA578FC\3DDF5FA578FC"
```

After the save game files have been patched you'll need to resign them using the TonyHawkSaveSigner python3 script using the following command: 
```
python TonyHawkSaveSigner.py thps4 xbox <save file>

Ex: python TonyHawkSaveSigner.py thps4 xbox ".\Release\Xbox\Tony Hawk's Pro Skater 4\NTSC\41560017\3DDF5FA578FC\3DDF5FA578FC"
```

## SystemLink Exploit
The save game for the system link exploit can be compiled using the instructions above with the "TonyHawksProSkater4-SystemLink-NTSC.asm" file.

To build the host xbe file you must first use XboxImageXploder to add a new code segment to a clean default.xbe from the NTSC version of the game:
```
XboxImageXploder.exe <xbe file> .hacks 1500
```

The "Virtual Address" for the .hacks segment must be 0x0030b280, if any other value is displayed the xbe will not work with the patch file.

Once the new code segment is added you can compile and apply the host patches to the xbe file using the following XePatcher command:
```
XePatcher.exe -p ".\Xbox\Tony Hawk's Pro Skater 4\TonyHawkProSkater4-SystemLink-Host-NTSC.asm" -proc x86 -bin <xbe file>
```

# Xbe Signing
All exploit payloads are designed to patch the Xbox kernel to use the Habibi RSA key pair. This means that xbe signatures are still enforced, only for a key pair we have the private key for. To
sign an xbe with the Habibi key you'll need to use xbedump (found on xbins) with the following command:
```
xbedump.exe <xbe file> -habibi
```

Please note the following: 
- Xbedump may complain that the header size is invalid but this is fine, just ignore it. 
- When you sign the xbe file xbedump will not write the changes to the xbe file specified on the command line. Instead it will create a new xbe file called out.xbe in the current working directory! 
- If you create your own xbe it cannot link to xbdm or the kernel will fail to resolve module imports when trying to load it. 
- The entry point and kernel import thunk address must be in retail format (meaning XOR'd with the retail xbe public key). If you created a custom xbe it will most likely be in debug format (XOR'd with debug xbe key). 
