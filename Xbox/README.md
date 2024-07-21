
# How to use


# Compiling
The game save and system link exploit payloads can be compiled and applied using XePatcher using the following command: 
```
XePatcher.exe -p <patch file> -proc x86 -b <save game file>
```

After the save game files have been patched you'll need to resign them using the XboxSaveSigner python script using the following command: 
```
python XboxSaveSigner.py <title id> <save file> -r
```

Where `title id` is the title id of the game:
TODO: table

# Xbe Signing
All exploit payloads are designed to patch the Xbox kernel to use the Habibi key pair. This means that xbe signatures are still enforced, only for a key pair we have the private key for. To
sign an xbe with the Habibi key you'll need to use xbedump with the following command:
```
xbedump.exe <xbe file> -habibi
```

Please note the following: 
- Xbedump may complain that the header size is invalid but this is fine, just ignore it. 
- When you sign the xbe file xbedump will not write the changes to the xbe file specified on the command line. Instead it will create a new xbe file called out.xbe in the current working directory! 
- If you create your own xbe it cannot link to xbdm or the kernel will fail to resolve module imports when trying to load it. 
- The entry point and kernel import thunk address must be in retail format (meaning XOR'd with the retail xbe public key). If you created a custom xbe it will most likely be in debug format (XOR'd with debug xbe key). 