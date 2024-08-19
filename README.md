# GBA snake game in assembly
Snake game written in assembly for the ARM7TDMI processor of the game boy advance.

# Dependencies
[Devkit PRO](https://sourceforge.net/projects/devkitpro/)

# Compile ASM code to GBA ROM
First, once you have downloaded Devkit Pro, place the files contained in src inside the **DEVKITARM-R41_WIN32/devkitARM/bin** folder.

After that, to compile the asm code, it's necessary to call **snake.bat**.

The bat file will execute all the necessary compilers in the DevKitARM folder, going from the asm file to an elf file, and finally to the final rom with **gba** extension.

# Final Result
![](https://github.com/AndreaFilippini/GBA_3DEngine/blob/main/images/snake.png)

Any GBA emulator, such as visual boy advance, can be used to view the final result.
