# Tony Hawk's Pro Strcpy
Tony Hawk's Pro Strcpy is a strcpy exploit that exists in the Tony Hawk's Pro Skater video game series and can be used to hack several different game consoles including Xbox, Xbox 360, Playstation 2, and Gamecube. This repository contains the exploit code and pre-made save game files that can be used to hack several different gaming consoles, as well as RCE variants that can be used to hack certain game consoles over the network.

## How to use
Consult the charts below to find out which versions of the game are supported for your console and what methods you can use (network or save game). Pre-compiled versions of the exploits can be found in the Releases page with the file name "TonyHawksProStrcpy-Exploit-Files.zip". For instructions on how to use each exploit please refer to the wiki page for your console.

## Supported Games and Consoles
The following tables summarize which consoles can be hacked by which versions of the game. Some versions listed are supported but a completed exploit has not yet been developed for it.

✔ = Exploit supported and written  
✖ = Exploitation possible but not yet written  
❌ = Exploitation not possible

**Network RCE** = Exploitation using network play (doesn't require game save or memory card)  
**NTSC** = Save game exploit for NTSC region  
**PAL** = Save game exploit for PAL region  
**Other Region** = Save game exploit for other regions

### Xbox
| Game | Network RCE | NTSC | PAL | Other Region | Notes |
| --- | --- | --- | --- | --- | --- |
| Tony Hawk's Pro Skater 3 | ✖ | ✔ | ✖ | N/A | |
| Tony Hawk's Pro Skater 4 | ✔ (NTSC) | ✔ | ✔ | ✔ | |
| Tony Hawk's Underground 1 | ❌ | ❌ | ❌ | ❌ | Game compiled using stack cookies, stack buffer overflow not possible |
| Tony Hawk's Underground 2 | ❌ | ❌ | ❌ | ❌ | Game compiled using stack cookies, stack buffer overflow not possible |
| Tony Hawk's American Wasteland | ✖ | ✔ | ✖ | N/A | |

### Xbox 360
**Full exploitation only possible on kernel 4548!!** 

The strcpy bug can be used on any kernel version to get ROP execution but without a hypervisor bug it won't be possible to get full code execution on the console. Currently the only known hypervisor bug is in kernel 4548 which is extremely old. The only reason I ported this bug to Xbox 360 was to show that a full stack software only exploit is possible on the console (and using a strcpy stack based buffer overflow). It's for demonstration purposes only and does not provide any value to the modding/homebrew community in modern times.
| Game | Network RCE | NTSC | PAL | Other Region | Notes |
| --- | --- | --- | --- | --- | --- |
| Tony Hawk's American Wasteland | ✖ | ✔ | ✖ | N/A | Only possible on kernel version 4548 |

### Playstation 2
Save game exploits have not been developed for PS2 because they serve no purpose. If you can already copy files to the memory card you can already install FreeMcBoot and you don't need the Tony Hawk save game exploit.
| Game | Network RCE | NTSC | PAL | Other Region | Notes |
| --- | --- | --- | --- | --- | --- |
| Tony Hawk's Pro Skater 3 | ✖ | N/A | N/A | N/A | |
| Tony Hawk's Pro Skater 4 | ✖ | N/A | N/A | N/A | |
| Tony Hawk's Underground 1 | ✖ | N/A | N/A | N/A | |
| Tony Hawk's Underground 2 | ✖ | N/A | N/A | N/A | |
| Tony Hawk's American Wasteland | ✖ | N/A | N/A | N/A | |

### Gamecube
| Game | Network RCE | NTSC | PAL | Other Region | Notes |
| --- | --- | --- | --- | --- | --- |
| Tony Hawk's Pro Skater 3 | ✖ | ✖ | ✖ | N/A | |
| Tony Hawk's Pro Skater 4 | ✖ | ✖ | ✖ | ✖ | |
| Tony Hawk's Underground 1 | ✖ | ✖ | ✖ | ✖ | |
| Tony Hawk's Underground 2 | ✖ | ✖ | ✖ | ✖ | |
| Tony Hawk's American Wasteland | ✖ | ✖ | ✖ | N/A | |

## The strcpy bug
The strcpy bug exists in the loading code for custom skate parks created with the "create a park" feature. By maliciously crafting a custom gap name in the park file you can trigger a stack overflow and overwrite a function return address. This can then be used to execute custom shell code and get full code execution on the console. This bug exists in several different versions of the game and can even be used to remotely hack a console over the network without the need for the client to obtain the hacked save files. For detailed information on how each exploit works for each game console see the README.md files in the sub-folders.
