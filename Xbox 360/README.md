# How to Use
**Full exploitation only possible on kernel 4548!!** 

The strcpy bug can be used on any kernel version to get ROP execution but without a hypervisor bug it won't be possible to get full code execution on the console. Currently the only known hypervisor bug is in kernel 4548 which is extremely old. The only reason I ported this bug to Xbox 360 was to show that a full stack software only exploit is possible on the console (and using a strcpy stack based buffer overflow). It's for demonstration purposes only and does not provide any value to the modding/homebrew community in modern times.

| Game | Network RCE | NTSC | PAL | Other Region | Notes |
| --- | --- | --- | --- | --- | --- |
| Tony Hawk's American Wasteland | ✖ | ✔ | ✖ | N/A | Only possible on kernel version 4548 |

✔ = Exploit supported and written  
✖ = Exploitation possible but not yet written  
❌ = Exploitation not possible

**Network RCE** = Exploitation using network play (doesn't require game save or memory card)  
**NTSC** = Save game exploit for NTSC region  
**PAL** = Save game exploit for PAL region  
**Other Region** = Save game exploit for other regions

## Save Game Exploit
The save game exploit files for Xbox 360 in the releases section include a gamer profile and hacked park file that are pre-signed for retail/devkit consoles. They can be copied to your console with no additional steps needed to resign them. You must copy these files to your console's HDD, loading them from a memory card or other storage device is not supported!

1. Copy the E0000XXXXXXXXXXX folder for your console type (retail or devkit) to Partition1\Content folder of your HDD (where the gamer profiles go).
2. Copy your boot.xex file to the root of partition 1 (it should be next to the "Content" folder). The xex file must be in retail format and have all restrictions removed, see the [Xex Signing](#xex-signing) section for how to do this. For demonstration purposes you can find a demo boot.xex in the "TonyHawksProStrcpy-Demo-Executables.zip" file in the releases section.
3. Launch Tony Hawk's American Wasteland.
4. Sign into the Player1 gamer profile.
5. Choose "Free skate" and once you get to the level select screen choose "custom park" and load the "Hack Xbox" park file.
6. Press "start game" and the exploit should trigger during the loading screen.

The console's ring of light (RoL) should change to solid orange if the exploit gets hypervisor code execution successfully. If the RoL doesn't change to orange then you're most likely on the wrong kernel version (must be 4548). If the RoL changes to orange but you get kicked to the dashboard or get an error along the lines of "could not start this game" it means your boot.xex file was either not found or is not in the correct format.

### Notes
- The exploit is based around the release version of the game. I don't believe a title update was every released for this game but if one was you'll need to clear that from your HDD before running the exploit.

# Compiling
To compile the patch file you'll need [XePatcher 3.0](http://icode4.coffee/files/XePatcher_3.0.zip) or newer, as well as an Xbox 360 container/save game tool that can extract/inject files into Xbox 360 game saves and resign them. See the [Game Save Signing](#game-save-signing) section for more information. This repository is not focused on how to resign the game save files and assumes you already have knowledge of how to do this.

Open the "E0000XXXXXXXXXXX\415607D4\00000001\Hack Xbox-Park" file for the console type you want to compile the game save for in an Xbox 360 container tool. Extract the "Hack Xbox-Park" file inside of the container (I'll refer to the extracted file as "hack_xbox.prk" from here on).

Unpack the hack_xbox.prk save file (byte flip) using the following command:
```
python TonyHawkSaveSigner.py thaw xbox360 <hack_xbox.prk file> -u
```

You should get the following output:
```
Save status: packed
Save is now unpacked
```

Save file status MUST be unpacked or the patch will not apply correctly.

Next you can apply the patch using the following XePatcher command:
```
XePatcher.exe -p <patch file> -proc ppc -bin <hack_xbox.prk file>

Ex: XePatcher.exe -p TonyHawkAmericanWasteland-NTSC-Retail.asm -proc ppc -bin hack_xbox.prk
```

You should get the following output:
```
Save status: unpacked
Save is now packed
Header checksum: Valid
Data checksum: Fixed
Successfully signed 'hack_xbox.prk'
```

Finally, you can use your Xbox 360 container/game save tool to inject the hack_xbox.prk file back into the "Hack Xbox-Park" container file. Note the file inside of the container must have its original file name (ie: you want to replace the file in the container and not inject the hack_xbox.prk file as a new file). You MUST also resign the container file after modifying it.

# Game Save Signing
Xbox 360 game saves are stored in a container file that has a strong cryptographic signature applied. To resign the game save files you'll need an Xbox 360 container/save game tool that can extract/inject files into Xbox 360 game saves and resign them. These tools also require an Xbox 360 keyvault file to resign game save files and will typically come with a retail keyvault file included. To sign the game save for Xbox 360 devkits you'll need to replace the keyvault file with a devkit keyvault file (retail game save must be signed with retail keyvault, devkit game save must be signed with devkit keyvault). Additionally, the game save and Xbox 360 gamer profile must have matching profile IDs or else the game save won't get detected.

This repository is not focused on how to resign the game save files and assumes you already have knowledge of how to do this. The profile/game save files included in the repo are already signed for their respective console types and have matching IDs, etc. The profile/game saves files in the releases section have already been signed for their respective platforms and only need to be copied to the console's HDD.

# Xex Signing
The "boot.xex" file must be in retail format and have all restrictions removed. This can be done with XexTool using the following command:
```
XexTool.exe -m r -r a <xex file>
```

The xex file must be bootable on the 4548 kernel version and not depend on any functionality that is only present on newer kernel versions.
