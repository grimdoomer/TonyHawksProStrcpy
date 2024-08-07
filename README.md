![thps_strcpy_logo](https://github.com/user-attachments/assets/5c9b9a63-7e09-4f2d-ba2c-ab5485ac59c8)

Tony Hawk's Pro Strcpy is a game save/network RCE exploit that can be used to hack several different game consoles including Xbox, Xbox 360, Playstation 2, and Gamecube. This repository contains the exploit code and pre-made save game files as well as RCE variants that can be used to hack certain game consoles remotely though network/LAN matches.

This exploit is intended to be used for hacking your own console and educational purposes only. Please do not use it maliciously. Also note that this is not the only strcpy bug that can be exploited over the network. Anyone still playing the exploitable Tony Hawk games should be extremely careful when using network play with people you don't know.

## How to use
Pre-made game saves and patches can be found in the Releases section, you should only need to compile the exploits from source code if you want modify/experiment with them.

For instructions on how to use the exploits, what versions of the game are support, and what exploit methods are available, please see the page for your console type:
- [Xbox](/Xbox)
- [Playstation 2](/Playstation%202)
- [Gamecube](/Gamecube)
- [Xbox 360](/Xbox%20360)

## The strcpy bug
The strcpy bug exists in the loading code for custom skate parks created with the "create a park" feature. The park editor allows players to create custom levels and one of the features lets you create a "gap" (a skateboarding term for an area between two platforms one must jump over) and name it up to 31 characters. By maliciously crafting a custom gap name in the park file you can trigger a stack/heap overflow and get control of the CPU instruction pointer. This can then be used to start a ROP chain (or execute shell code) and further exploit the console for full code execution. 

This bug exists in several different versions of the game and can even be used over the network via LAN matches to remotely hack clients without the need for them to obtain the hacked save files. For detailed information on how the exploit works for each game console see the notes in the exploit source files.


Logo template from: [bekoha](https://github.com/bekoha/bekoha.github.io)
