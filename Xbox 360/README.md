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
The save game exploit files for Xbox 360 include a gamer profile and hacked park file that are pre-signed for retail consoles. You must copy these files to your console's HDD, loading them from a memory card or other storage device is not supported!

1. Copy the <TODO> folder to Partition1\Content folder of your HDD (where the user profiles go).
2. Copy your boot.xex file to the root of partition 1 (it should be next to the "Content" folder).
3. Launch Tony Hawk's American Wasteland.

### Notes
- The exploit is based around the release version of the game. I don't believe a title update was every released for this game but if one was you'll need to clear that from your HDD before running the exploit.

# Compiling


# Xex Signing
The "boot.xex" file must be in retail format and have all restrictions removed. This can be done with XexTool using the following command:
```
XexTool.exe -m r -r a <xex file>
```

The xex file must be bootable on the 4548 kernel version and not depend on any functionality that is only present on newer kernel versions.
