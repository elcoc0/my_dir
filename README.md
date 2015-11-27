# Own implementation of the PowerShell command dir (Coded in C and MASM)

This is an academic project to learn more about low level language assembly, I developped a GUI program for browsing a folder and its subfolders. Both programs use the WIN32 API.

You can see a screenshot of the MASM program in action:

![My dir Powershell CMD (MASM)](http://i.imgur.com/Jtl8pre.png)

## The C program
### Installation

Compile the program using the `Makefile`:

```compiling
make
```

You may now execute the program.

## The MASM program
### Installation

Execute the `make.bat` file (you may need to modify the line pointing to the masm compiler folder).

You may now execute  the program.

## Possible improvements
* Separate the process thread from the main one, important folders freeze the GUI interface (C program)

* Add a browser folder selection (MASM program)
