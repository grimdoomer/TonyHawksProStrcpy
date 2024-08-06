# How to Use
Only a network exploit is available for PS2, save game exploits have not been developed because they serve no purpose. If you can already copy files to the memory card you can already install FreeMcBoot and you don't need the Tony Hawk save game exploit.

| Game | Network RCE | NTSC | PAL | Other Region | Notes |
| --- | --- | --- | --- | --- | --- |
| Tony Hawk's Pro Skater 3 | ✖ | N/A | N/A | N/A | |
| Tony Hawk's Pro Skater 4 | ✔ | N/A | N/A | N/A | |
| Tony Hawk's Underground 1 | ✖ | N/A | N/A | N/A | |
| Tony Hawk's Underground 2 | ✖ | N/A | N/A | N/A | |
| Tony Hawk's American Wasteland | ✖ | N/A | N/A | N/A | |

✔ = Exploit supported and written  
✖ = Exploitation possible but not yet written  
❌ = Exploitation not possible

**Network RCE** = Exploitation using network play (doesn't require game save or memory card)  
**NTSC** = Save game exploit for NTSC region  
**PAL** = Save game exploit for PAL region  
**Other Region** = Save game exploit for other regions

## Network Exploit
Pre-compiled patch files/game saves can be found in the Releases section. The network exploit has been tested using PCSX2 for the host and a phat Playstation 2 console as the client. Running the host setup from a real PS2 console has not been tested but should work.

To prep the PCSX2 host:
1. Extract the Tony Hawk's Pro Skater 4 ISO to a folder on your computer.
2. Use [XDelta](https://www.romhacking.net/utilities/598/) to apply the "Playstation 2\Tony Hawk's Pro Skater 4\NTSC\TonyHawkProSkater4-Lan-SLUS_205.04.xdelta" patch file to the "SLUS_205.04" file extracted in step 1.
3. Rebuild the ISO using the patched "SLUS_205.04" file and your PAYLOAD.ELF file which is any elf file you want to send to the client. There are some requirements for what elf files can be used, see the [Payload Elf](#payload-elf) section for more information. See [Executable patch](#executable-patch) section for an example ImgBurn command to rebuild the ISO.
4. Run PCSX2 and configure the following options:
   - Assign the "Playstation 2\Tony Hawk's Pro Skater 4\NTSC\THPS4-Host-Lan-VMC.ps2" file to memory card slot 1
   - Enable the network adapter/ethernet port, set the device type to "PCAP Bridged" and select your PC's network interface (either your ethernet port or wifi connection)
5. Boot the rebuilt game ISO and select "Network Play" and configure the network adapter.

To run the exploit:
1. Boot the rebuilt game ISO in PCSX2.
2. Choose "Network Play" and when prompted for the game type choose LAN game.
3. Select "Host Game" and change the level to the "Hack PS2" game save.
4. Start the match.
5. On the client console boot Tony Hawk's Pro Skater 4.
6. Choose "Network Play" and when prompted for the game type choose LAN game.
7. Select "Join Game" and you should see the host's game. If not check your network settings in PCSX2.
8. Join the host's game, it should take 1-2 minutes for the payload to transfer depending on how large it is.
9. When the payload is fully received the client will attempt to launch it. During this process the screen will change colors rapidly to indicate what part of the loading process it's at. If everything works correctly the payload will launch and you're done. If something goes wrong you can use the following color codes to determine what the issue was:
    - Red: failed to allocate memory for the payload.elf file
    - Yellow: payload was received, bootstrap process initialized
    - Purple: bootstrap init finished
    - Blue: bootstrap started
    - Cyan: clearing user memory
    - Green: payload executed

### Payload Elf
The PAYLOAD.ELF file can be any elf file you want to send to the client and have them run. I recommend using uLaunchElf which will allow the client console to boot FreeMcBoot installer from a usb stick and softmod their console. 

Any elf can be used but it must be self contained, the elf cannot load any additional files from another storage device (because the client won't have them on their console). The elf file will be launched from RAM so the smaller the better. It's also recommended to compress the elf file using [Ps2-Packer](https://github.com/ps2dev/ps2-packer) as these will have an easier time booting than a non-compressed elf. 

Some elf files may not launch or cause issues on the client's side. This is because the elf file is downloaded to RAM (there's no common persistent storage mechanism on all PS2 consoles like the internal HDD on an Xbox), and then has to be loaded at the correct base address for it to function. Essentially, you'll need to fit two copies of the elf in RAM at different locations before it will run. This is why it's recommended to use ps2-packer as it will decrease the elf size and the decompression stub it uses will require the elf be loaded at the end of RAM, away from where the game is loaded.

# Compiling
Preping the game executable and compiling patches for the network exploit will require either WSL or a linux VM/machine. You'll need to install the [Ps2Toolchain](https://github.com/ps2dev/ps2toolchain) to be able to use the mips64r5900el-ps2 GNU tools. You'll also need the following tools:
- [XePatcher 3.0](http://icode4.coffee/files/XePatcher_3.0.zip) or newer
- [Mymc](https://github.com/ps2dev/mymc) python 2.7 script
- An ISO extractor/rebuilder tool, I used ImgBurn

## Network Exploit
The network exploit has two patches, one for the game executable and one for the game save that gets sent to the clients. Instructions for compiling and applying both patches can be found below.

### Game save patch
First you'll need to compile the TonyHawkProSkater4-Lan-Park-NTSC.s file in the linux environment by running `make` or `make park from the "TonyHawksProStrcpy\Playstation 2\Tony Hawk's Pro Skater 4" folder. You should get output similar to the following:
```
mips64r5900el-ps2-elf-as TonyHawkProSkater4-Lan-Park-NTSC.s -o obj/TonyHawkProSkater4-Lan-Park-NTSC.elf
mips64r5900el-ps2-elf-objcopy -j .text obj/TonyHawkProSkater4-Lan-Park-NTSC.elf -O binary bin/TonyHawkProSkater4-Lan-Park-NTSC.bin
```

Next you'll need to apply the patch to the game save file by running the following XePatcher command in the Windows environment:
```
XePatcher.exe -pb <compiled path file> -proc x86 -bin <save file> -o <output file>

Ex: XePatcher.exe -pb .\bin\TonyHawkProSkater4-Lan-Park-NTSC.bin -proc x86 -bin .\BASLUS-20504oibzbwmc\BASLUS-20504oibzbwmc -o .\BASLUS-20504oibzbwmc\BASLUS-20504oibzbwmc_patched
```

After the save game file has been patched you'll need to resign it using the TonyHawkSaveSigner python3 script using the following command:
```
python TonyHawkSaveSigner.py thps4 ps2 <save file>

Ex: python TonyHawkSaveSigner.py thps4 ps2 .\BASLUS-20504oibzbwmc\BASLUS-20504oibzbwmc_patched
```

Finally you'll need to inject the save game file into the "THPS4-Host-Lan-VMC.ps2" virtual memory card image using the following commands for the Mymc python2 script:
```
python mymc.py <vmc file> remove BASLUS-20504oibzbwmc/BASLUS-20504oibzbwmc
python mymc.py <vmc file> add <save file>
python mypc.py <vmc file> rename <save file name> BASLUS-20504oibzbwmc/BASLUS-20504oibzbwmc

Example:
python mymc.py .\THPS4-Host-Lan-VMC.ps2 remove BASLUS-20504oibzbwmc/BASLUS-20504oibzbwmc
python mymc.py .\THPS4-Host-Lan-VMC.ps2 add .\BASLUS-20504oibzbwmc\BASLUS-20504oibzbwmc_patched
python mypc.py .\THPS4-Host-Lan-VMC.ps2 rename BASLUS-20504oibzbwmc_patched BASLUS-20504oibzbwmc/BASLUS-20504oibzbwmc
```

You can now use the VMC file in PCSX2 to host a network game with a real Playstation 2 console.

### Executable patch
The host executable patch must be applied to a clean version of the NTSC game elf "SLUS_205.04" (SHA1: F5D5E5A93CD90180FE8D87D4A945557DE3F82B1B). 

First you'll need to prepare the game executable by adding a new executable code segment to it. Copy the "SLUS_205.04" file from the game disc to the "TonyHawksProStrcpy\Playstation 2\Tony Hawk's Pro Skater 4" folder. Then run `make prep_elf` in the linux environment which should give output similar to the following:
```
dd if=/dev/zero of=obj/section_data.bin bs=4096 count=1
1+0 records in
1+0 records out
4096 bytes (4.1 kB, 4.0 KiB) copied, 5.8628e-05 s, 69.9 MB/s
mips64r5900el-ps2-elf-objcopy --add-section .hacks=obj/section_data.bin --set-section-flags .hacks=alloc,code SLUS_205.04 SLUS_205.04_patched
mips64r5900el-ps2-elf-objcopy: SLUS_205.04_patched: warning: allocated section `.hacks' not in segment
mips64r5900el-ps2-elf-objcopy --adjust-section-vma .hacks=1044480 SLUS_205.04_patched SLUS_205.04_patched
mips64r5900el-ps2-elf-objcopy: stVe7sqS: warning: allocated section `.hacks' not in segment
mips64r5900el-ps2-elf-objcopy --set-section-alignment .hacks=16 SLUS_205.04_patched SLUS_205.04_patched
mips64r5900el-ps2-elf-objcopy: str0iKLR: warning: allocated section `.hacks' not in segment
```

In the same folder you should now have a "SLUS_205.04_patched" file. Next you can compile the patch file by running `make` or `make host` which should give output similar to the following:
```
mips64r5900el-ps2-elf-as TonyHawkProSkater4-Lan-Host-NTSC.s -o obj/TonyHawkProSkater4-Lan-Host-NTSC.elf
mips64r5900el-ps2-elf-objcopy -j .text obj/TonyHawkProSkater4-Lan-Host-NTSC.elf -O binary bin/TonyHawkProSkater4-Lan-Host-NTSC.bin
```

You should now have a TonyHawkProSkater4-Lan-Host-NTSC.bin file in the bin folder.

Next you'll need to apply the TonyHawkProSkater4-Lan-Host-NTSC.bin patch file to the new elf file using the following XePatcher command in the Windows environment:
```
XePatcher.exe -pb <compiled patch file> -elf <patched elf file>

Ex: XePatcher.exe -pb .\bin\TonyHawkProSkater4-Lan-Host-NTSC.bin -elf SLUS_205.04_patched
```

Lastly you'll need to replace the "SLUS_205.04" file in the game ISO with the "SLUS_205.04_patched" file you created. Don't forget to include your PAYLOAD.ELF file in the ISO as well. I used ImgBurn to rebuild the game ISO from the extracted files, here's an example command on how to do that:
```
ImgBurn.exe /MODE BUILD /OUTPUTMODE IMAGEFILE /SRC <src directory> /DEST <output iso file> /OVERWRITE YES /ROOTFOLDER YES /START /CLOSE /VOLUMELABEL "Tony Hawk Pro Skater 4" /NOIMAGEDETAILS
```
