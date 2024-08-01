# How to Use
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
2. Once your xbe has been signed and copied into the 41560XXX\3DDF5FA578FC folder you can copy the 41560XXX folder to your memory card and then transfer it to your console's HDD. The save must be loaded from your console's HDD, loading it from the memory card is not supported.
3. Launch the Tony Hawk game you're using for the exploit and choose the free skate option from the main menu (varies slightly per game).
4. When you get to the level select screen choose "custom park" and load the "Hack Xbox" game save.
5. After the save is loaded choose "start game". Depending on what version of the game you're using the exploit should trigger during the loading screen. For Tony Hawk's Pro Skater 3 you'll you'll need to wait until the player spawns in and then press pause and quit back to the main menu which should trigger the exploit.

## SystemLink Exploit
The system link exploit is currently only supported on the NTSC version of Tony Hawk's Pro Skater 4. The exploit works by running a patched version of the game on an already modded Xbox that will act as the host of the match. When the client joins the match the host will send the malicious park file to the client and get code execution on their console. Then a file transfer will start and send an arbitrary xbe file to the client that gets saved on their HDD. Once the file transfer completes the client will launch the xbe file, typically a softmod installer xbe, and allow them to softmod their console. 

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
The game save expoits can be compiled and applied to the save files using the following XePatcher command: 
```
XePatcher.exe -p <patch file> -proc x86 -b <save game file>

Ex: XePatcher.exe -p ".\Xbox\Tony Hawk's Pro Skater 4\TonyHawkProSkater4-NTSC.asm" -proc x86 -bin ".\Release\Xbox\Tony Hawk's Pro Skater 4\NTSC\41560017\3DDF5FA578FC\3DDF5FA578FC"
```

You must apply the patch to the corresponding save file for the version of the game you chose (ie: the american wasteland patch must be used with the american wasteland save files).

After the save game files have been patched you'll need to resign them using the TonyHawkSaveSigner python3 script using the following command: 
```
python TonyHawkSaveSigner.py <game version> xbox <save file>

Ex: python TonyHawkSaveSigner.py thps4 xbox ".\Release\Xbox\Tony Hawk's Pro Skater 4\NTSC\41560017\3DDF5FA578FC\3DDF5FA578FC"
```

The possible game versions are: 
- thps3 = Tony Hawk's Pro Skater 3
- thps4 = Tony Hawk's Pro Skater 4
- thaw = Tony Hawk's American Wasteland

You must use the correct game id for the version of the game you're patching or the save file will not work and appear as "damaged" on the console.

## SystemLink Exploit
The save game for the system link exploit can be compiled using the instructions above with the "TonyHawksProSkater4-SystemLink-NTSC.asm" file. It must be applied to the Tony Hawk's Pro Skater 4 save file.

To build the host xbe file you must first use XboxImageXploder v1.1 to add a new code segment to a clean default.xbe from the NTSC version of the game (SHA1: 22607A9C6DA95813884139E8A20971C4C3D23517):
```
XboxImageXploder.exe <xbe file> .hacks 4096
```

The output from XboxImageXploder should match the following, if it doesn't the patch will not work:
```
Section Name:           .hacks
Virtual Address:        0x0030c000
Virtual Size:           0x00001000
File Offset:            0x001d1000
File Size:              0x00001000
```

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
