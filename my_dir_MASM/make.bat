@echo off
 
if exist "my_dir.obj" del "my_dir.obj"
if exist "my_dir.exe" del "my_dir.exe"
 
\masm32\bin\ml /c /coff "my_dir.asm"
if errorlevel 1 goto errasm
 
\masm32\bin\PoLink /SUBSYSTEM:WINDOWS "my_dir.obj"
if errorlevel 1 goto errlink
dir "my_dir.*"
goto TheEnd
 
:errlink
echo _
echo Link error
goto TheEnd
 
:errasm
echo _
echo Assembly Error
goto TheEnd
 
:TheEnd
pause

