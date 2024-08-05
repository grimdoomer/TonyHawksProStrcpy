# How to Use

| Game | Network RCE | NTSC | PAL | Other Region | Notes |
| --- | --- | --- | --- | --- | --- |
| Tony Hawk's Pro Skater 3 | N/A | ✖ | ✖ | N/A | |
| Tony Hawk's Pro Skater 4 | N/A | ✔ | ✖ | ✖ | |
| Tony Hawk's Underground 1 | N/A | ✖ | ✖ | ✖ | |
| Tony Hawk's Underground 2 | N/A | ✖ | ✖ | ✖ | |
| Tony Hawk's American Wasteland | N/A | ✖ | ✖ | N/A | |

✔ = Exploit supported and written  
✖ = Exploitation possible but not yet written  
❌ = Exploitation not possible

**Network RCE** = Exploitation using network play (doesn't require game save or memory card)  
**NTSC** = Save game exploit for NTSC region  
**PAL** = Save game exploit for PAL region  
**Other Region** = Save game exploit for other regions

## Save Game Exploit
1. Copy the "52-GT4E-NGCkwhjnlgcNGCkwhjnlgc.gci" save file to your memory card. You'll need an already modded gamecube or wii console to do this.
2. Copy your homebrew boot.gci file to your memory card, you can obtain this from the latest swiss release in the "GCI" folder.
3. Launch the Tony Hawk game you're using for the exploit and choose free skate option from the main menu.
4. When you get to the level select screen choose "custom park" and load the "Hack Gamecube" game save.
5. After the save is loaded choose "start game". The exploit will trigger during the loading screen and your homebrew boot.gci file should run.

# Compiling
To compile the exploit files you need XePatcher 3.0 or newer.

The clean "52-GT4E-NGCkwhjnlgcNGCkwhjnlgc.gci" file first needs to be unpacked (byte flipped) before the patch can be applied. Use the following command to unpack the save file:
```
python TonyHawkSaveSigner.py thps4 gc <save file> -u
```

You should get the following output, the save state MUST be unpacked or the patch will not apply correctly:
```
Save status: packed
Save is now unpacked
```

Next you can apply the exploit patch to the save file using the following XePatcher command:
```
XePatcher.exe -p <patch file> -proc ppc -bin <save file>

Ex: XePatcher.exe -p TonyHawkProSkater4-NTSC.s -proc ppc -bin 52-GT4E-NGCkwhjnlgcNGCkwhjnlgc.gci
```

Finally you must re-pack and fix the checksums on the save file using the following command:
```
python TonyHawkSaveSigner.py thps4 gc <save file>
```

You should get the following output:
```
Save status: unpacked
Save is now packed
Header checksum: Valid
Data checksum: Fixed
Successfully signed '52-GT4E-NGCkwhjnlgcNGCkwhjnlgc_mod_out.gci'
```

## Exploit Notes
The exploit is based on the exploits developed by FIX94 that you can find [here](https://github.com/FIX94). I chose to write mine in pure assembly to remove the need for wsl/linux and setting up the ppc cross compiler. The "loader.bin" file is from [gc-exploit-common-loader](https://github.com/FIX94/gc-exploit-common-loader/tree/5463ce0365575148b676e46f016c1a3d232b4f6d) repository from FIX94. 
