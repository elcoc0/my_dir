;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; File Name         : my_dir.asm
; Created By        : elcoc0
; Creation Date     : September 30th, 2015
; Last Change       : November  8th, 2015 at 11:17:27 PM
; Last Changed By   : elcoc0
; Purpose           : Own implementation of dir function (PowerShell)
;*
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

title MyDir

.386
.model flat,stdcall
option casemap:none

include c:\masm32\include\masm32rt.inc

WinMain proto hInst:HINSTANCE
WndProc proto hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
threadHandler proto path:DWORD
myDir proto handle:HWND, pathNotFormated:DWORD
appendTextToElement proto handle:HWND, text:DWORD
printDateTime proto handle:HWND, ft:FILETIME
strCompare proto str1:DWORD, str2:DWORD

; Macro for getting the 16 most significant bits of a DWORD
; The LOWORD macro is not defined, we can use AX (which represents the 16 least significant bits of a DWORD)
HIWORD macro doubleWord
    mov  eax, doubleWord
    shr  eax, 16
    and  eax, 0ffffh
endm

.CONST
; custom message received when the "process" thread is finished
WM_FINISH_THREAD equ WM_USER+100h
; ID for each graphical component
ID_LABEL_HPATH equ 1
ID_EDIT_PATH equ 2
ID_BUTTON_LAUNCH equ 3
ID_BUTTON_CLEAR equ 4
ID_BUTTON_STOP equ 5
ID_EDIT_DIR equ 6

.DATA
; Constants for the window class
className db "SimpleWinClass", 0
appName	db "My dir PowerShell CMD (Coded in MASM)", 0

; Constants to declare a graphical component
STATIC_ELEMENT db "STATIC", 0
EDIT_ELEMENT db "EDIT", 0
BUTTON_ELEMENT db "BUTTON", 0

; Value for each graphical component
VALUE_BUTTON_LAUNCH db "LAUNCH", 0
VALUE_BUTTON_CLEAR db "CLEAR", 0
VALUE_BUTTON_STOP db "STOP", 0
VALUE_EDIT_LABEL db "Enter a correct folder path:", 0

; boolean to know if a "process" thread is already launched
isLaunched db 0

; String constants use in the program
STRING_SPACE db " ", 0
STRING_STOP_THREAD db 13, 10, "The process has been successfully stopped. You may clear the console by cliking on the related button", 13, 10, 0
STRING_DOT db ".", 0
STRING_DOTDOT db "..", 0
WSPRINTF_SLASHED_ASTERISK_FORMATED_PATH db "%s/*", 0
WSPRINTF_SLASHED_FORMATED_PATH db "%s/", 0
WSPRINTF_LISTING_FOLDER db 13, 10, "Listing content of folder: %s", 13, 10, 0
WSPRINTF_PATH_NOT_FOUND db "Path not found: %s",13, 10, 0
WSPRINTF_CPT_FILE db "File [%d]: ", 0
WSPRINTF_REP db "  <REP>  %s",13, 10, 0
WSPRINTF_NOT_REP db "               %s",13, 10, 0
WSPRINTF_CONTINUE_LISTING_FOLDER db 13, 10, "Continue listing content of folder : %s", 13, 10, 0
WSPRINTF_FINISHING_LISTING_FOLDER db 13, 10, "The folder %s has been listed successfully", 13, 10, 0
WSPRINTF_PATH_NOT_FOLDER db "The path is not a folder: %s", 13, 10, 0
WSPRINTF_SLASHED_NEXT_FOLDER db "%s/%s", 0

.DATA?
; Useful handles
hInstance HINSTANCE ?
hWindow HWND ?
hEditDir HWND ?
hThread HWND ?

buffer db 4096 DUP (?)
pathThread db MAX_PATH DUP (?)
idThread dw ?
exitCodeThread dw ?


.CODE

;========================================================================================
; WinMain function (GUI oriented)                                                       ;
;========================================================================================
;
; Create the window empty and loop for dispatching messages event
;
; INPUT: 	hInst = Handle to the current instance of application
;
; OUTPUT:	eax	= Stored in eax the last wParam value of the message received
;				  When the program stop successfully, the last message received is WM_QUIT
WinMain proc hInst:HINSTANCE
	
	LOCAL	wc:WNDCLASSEX
	LOCAL	msg:MSG

	mov	wc.cbSize,SIZEOF WNDCLASSEX
	mov	wc.style, CS_HREDRAW OR CS_VREDRAW OR CS_DBLCLKS
	mov	wc.lpfnWndProc, OFFSET WndProc
	mov	wc.cbClsExtra,NULL
	mov	wc.cbWndExtra,NULL
	push hInst
	pop	wc.hInstance
	mov	wc.hbrBackground,COLOR_WINDOW+1
	mov	wc.lpszMenuName,NULL
	mov	wc.lpszClassName, OFFSET className

	; invoke LoadIcon, NULL, IDI_APPLICATION
	push IDI_APPLICATION
	push NULL
	call LoadIcon
	mov	wc.hIcon, eax
	mov	wc.hIconSm, eax
	
	; invoke LoadCursor, NULL, IDC_ARROW
	push IDC_ARROW
	push NULL
	call LoadCursor
	mov	wc.hCursor, eax

	; invoke RegisterClassEx, addr wc
	lea ebx, wc
	push ebx
	call RegisterClassEx

	; invoke CreateWindowEx, NULL, OFFSET className, OFFSET appName, WS_OVERLAPPED OR WS_SYSMENU,CW_USEDEFAULT, CW_USEDEFAULT, WIDTH_MAIN_WINDOW, HEIGHT_MAIN_WINDOW, NULL, NULL, hInst, NULL
	push NULL
	push hInst
	push NULL
	push NULL
	push 600
	push 800
	push CW_USEDEFAULT
	push CW_USEDEFAULT
	push WS_OVERLAPPED OR WS_SYSMENU
	push OFFSET appName
	push OFFSET className
	push NULL
	call CreateWindowEx
	mov hWindow, eax

	; invoke ShowWindow, handle, SW_SHOWNORMAL
	push SW_SHOWNORMAL
	push hWindow
	call ShowWindow

	; invoke UpdateWindow, handle
	push hWindow
	call UpdateWindow

	; boucle de gestion des evenements
	mainLoop:
	; invoke GetMessage, ADDR msg, NULL, 0, 0
	push 0
	push 0
	push NULL
	lea ebx, msg
	push ebx
	call GetMessage
	cmp eax, 0
	je endLoop

	; invoke TranslateMessage, ADDR msg
	lea ebx, msg
	push ebx
	call TranslateMessage

	; invoke DispatchMessage, ADDR msg
	lea ebx, msg
	push ebx
	call DispatchMessage
	jmp	mainLoop
	
	endLoop:
	mov eax, msg.wParam
	ret

WinMain endp

;========================================================================================
; WndProc function                                                                      ;
;========================================================================================
;
; Function called when each message is dispatched
;
; INPUT: 	path 	= path of the folder to explore
;			uMsg 	= message dispatched
;			wParam 	= information about the message
;			lParam 	= information about the message
;
; OUTPUT: 	eax = 0 on success
; 
; SEE:		check the MSDN WIN32 API documentation for more information
WndProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
	LOCAL ps:PAINTSTRUCT
	LOCAL rect:RECT
	LOCAL hdc:HDC
	LOCAL not_formated_path[MAX_PATH]:byte

	; switch WM events
	mov	eax, uMsg
	; the window has been successfully created, now we create all the components of the windows
	cmp eax, WM_CREATE
	jne evtNotCreate
	
	; invoke CreateWindowEx, NULL, ADDR EDIT_ELEMENT, ADDR VALUE_EDIT_LABEL, WS_CHILD OR WS_VISIBLE OR ES_READONLY, 20, 10, 200, 30, hWnd, ID_LABEL_HPATH, hInstance, NULL
	push NULL
	push hInstance
	push ID_LABEL_HPATH
	push hWnd
	push 30
	push 250
	push 10
	push 20
	push WS_CHILD OR WS_VISIBLE OR ES_READONLY
	push OFFSET VALUE_EDIT_LABEL
	push OFFSET EDIT_ELEMENT
	push NULL
	call CreateWindowEx
	
	; invoke CreateWindowEx, NULL, ADDR EDIT_ELEMENT, NULL, WS_BORDER OR WS_CHILD OR WS_VISIBLE, 20, 50, 380, 30, hWnd, ID_EDIT_PATH, hInstance, NULL
	push NULL
	push hInstance
	push ID_EDIT_PATH
	push hWnd
	push 30
	push 380
	push 50
	push 20
	push WS_BORDER OR WS_CHILD OR WS_VISIBLE OR SS_NOTIFY
	push NULL
	push OFFSET EDIT_ELEMENT
	push NULL
	call CreateWindowEx
	
	; invoke CreateWindowEx, NULL, ADDR BUTTON_ELEMENT, ADDR VALUE_BUTTON_LAUNCH, WS_BORDER OR WS_CHILD OR WS_VISIBLE OR BS_PUSHBUTTON, 420, 50, 100, 30, hWnd, ID_BUTTON_LAUNCH, hInstance, NULL
	push NULL
	push hInstance
	push ID_BUTTON_LAUNCH
	push hWnd
	push 30
	push 100
	push 50
	push 420
	push WS_BORDER OR WS_CHILD OR WS_VISIBLE OR BS_PUSHBUTTON
	push OFFSET VALUE_BUTTON_LAUNCH
	push OFFSET BUTTON_ELEMENT
	push NULL
	call CreateWindowEx
	
	; invoke CreateWindowEx, NULL, ADDR BUTTON_ELEMENT, ADDR VALUE_BUTTON_CLEAR, WS_BORDER OR WS_CHILD OR WS_VISIBLE OR BS_PUSHBUTTON, 540, 50, 100, 30, hWnd, ID_BUTTON_CLEAR, hInstance, NULL
	push NULL
	push hInstance
	push ID_BUTTON_CLEAR
	push hWnd
	push 30
	push 100
	push 50
	push 540
	push WS_BORDER OR WS_CHILD OR WS_VISIBLE OR BS_PUSHBUTTON
	push OFFSET VALUE_BUTTON_CLEAR
	push OFFSET BUTTON_ELEMENT
	push NULL
	call CreateWindowEx
	
	; invoke CreateWindowEx, NULL, ADDR BUTTON_ELEMENT, ADDR VALUE_BUTTON_STOP, WS_BORDER OR WS_CHILD OR WS_VISIBLE OR BS_PUSHBUTTON, 660, 50, 100, 30, hWnd, ID_BUTTON_STOP, hInstance, NULL
	push NULL
	push hInstance
	push ID_BUTTON_STOP
	push hWnd
	push 30
	push 100
	push 50
	push 660
	push WS_BORDER OR WS_CHILD OR WS_VISIBLE OR BS_PUSHBUTTON
	push OFFSET VALUE_BUTTON_STOP
	push OFFSET BUTTON_ELEMENT
	push NULL
	call CreateWindowEx
	
	; invoke CreateWindowEx, NULL, ADDR EDIT_ELEMENT, NULL, WS_BORDER OR WS_CHILD OR WS_VISIBLE OR ES_MULTILINE OR ES_READONLY OR ES_AUTOVSCROLL OR ES_AUTOHSCROLL OR WS_VSCROLL, 20, 100, 740, 450, hWnd, ID_EDIT_DIR, hInstance, NULL
	push NULL
	push hInstance
	push ID_EDIT_DIR
	push hWnd
	push 450
	push 740
	push 100
	push 20
	push WS_BORDER OR WS_CHILD OR WS_VISIBLE OR ES_MULTILINE OR ES_READONLY OR ES_AUTOVSCROLL OR ES_AUTOHSCROLL OR WS_VSCROLL OR WS_HSCROLL
	push NULL
	push OFFSET EDIT_ELEMENT
	push NULL
	call CreateWindowEx
	mov hEditDir, eax

	; the max value of the interactive console graphical component (hEditDir)
	; invoke SendMessage, hEditDir, EM_SETLIMITTEXT, 0FFFFFFFFh, 0h
	push 0h
	push 0FFFFFFFFh
	push EM_SETLIMITTEXT
	push hEditDir
	call SendMessage
	jmp evtSwitchEnd

	evtNotCreate:
	; the window has been closed
	cmp eax, WM_CLOSE
	jne	evtNotClose

	; invoke DestroyWindow, hWnd
	push hWnd
	call DestroyWindow

	evtNotClose:
	; the window has received a command
	cmp eax, WM_COMMAND
	jne evtNotCommand
	
	HIWORD wParam
	; The command is a simple click on a button
	cmp eax, BN_CLICKED
	jne evtSwitchEnd

	mov eax, wParam
	; The click happened on the button launch
	cmp ax, ID_BUTTON_LAUNCH
	jne evtNotButtonLaunch
	
	; invoke GetDlgItemText, hWindow, ID_EDIT_PATH, ADDR pathThread, MAX_PATH
	push MAX_PATH
	push OFFSET pathThread
	push ID_EDIT_PATH
	push hWindow
	call GetDlgItemText

	; if the thread has not been already launched
	cmp isLaunched, 0
	jne evtSwitchEnd

	; invoke CreateThread, NULL, NULL, ADDR threadHandler, ADDR pathThread, 0, ADDR idThread
	push OFFSET idThread
	push 0
	push OFFSET pathThread
	push OFFSET threadHandler
	push NULL
	push NULL
	call CreateThread
	
	mov isLaunched, 1
	mov hThread, eax
	jmp evtSwitchEnd

	evtNotButtonLaunch:
	; The click happened on the button clear
	cmp ax, ID_BUTTON_CLEAR
	jne evtNotButtonClear

	; invoke SetDlgItemText, hWnd, ID_EDIT_PATH, NULL
	push NULL
	push ID_EDIT_PATH
	push hWnd
	call SetDlgItemText
	
	; invoke SetDlgItemText, hWnd, ID_EDIT_DIR, NULL
	push NULL
	push ID_EDIT_DIR
	push hWnd
	call SetDlgItemText
	jmp evtSwitchEnd

	evtNotButtonClear:
	; The click happened on the button stop
	cmp ax, ID_BUTTON_STOP
	jne evtSwitchEnd
	cmp isLaunched, 1
	jne evtSwitchEnd
	; invoke TerminateThread, hThread, ADDR exitCodeThread
	push OFFSET exitCodeThread
	push hThread
	call TerminateThread
	
	mov isLaunched, 0
	; invoke appendTextToElement, handle, ADDR STRING_STOP_THREAD
	push OFFSET STRING_STOP_THREAD
	push hEditDir
	call appendTextToElement
	jmp evtSwitchEnd
		
	evtNotCommand:
	; The thread has finished is process, it can be closed now
	cmp eax, WM_FINISH_THREAD
	jne evtNotFinishThread

	; invoke TerminateThread, hThread, ADDR exitCodeThread
	push OFFSET exitCodeThread
	push hThread
	call TerminateThread
	mov isLaunched, 0
	
	; invoke appendTextToElement, hEditDir, ADDR STRING_STOP_THREAD
	PUSH OFFSET STRING_STOP_THREAD
	PUSH hEditDir
	CALL appendTextToElement
	jmp evtSwitchEnd
	
	evtNotFinishThread:
	; WM_DESTROY event
	cmp eax, WM_DESTROY
	jne	evtNotDestroy
	; invoke PostQuitMessage,NULL
	push NULL
	call PostQuitMessage
	jmp	evtSwitchEnd

	evtNotDestroy:
	; By default call DefWindowProc
	; invoke DefWindowProc,hWnd,uMsg,wParam,lParam
	push lParam
	push wParam
	push uMsg
	push hWnd
	call DefWindowProc
	ret

	evtSwitchEnd:
	xor eax, eax
	ret
WndProc endp

;========================================================================================
; threadHandler function                                                                ;
;========================================================================================
;
; Thread handler for the my dir process, separating GUI from process won't freeze the app
;
; INPUT: 	path = path of the folder to explore
;
; OUTPUT: 	No meaningful values returned
threadHandler proc path:DWORD

	; check if the path is ended by a slash or an antislash
	; the path is pass to the function myDir without any slash
	; invoke lstrlen, path
	PUSH path
	CALL lstrlen
	
	mov ebx, eax
	mov edx, path

	cmp  BYTE PTR [edx + ebx - 1], '/'
	je isSlashed
	cmp  BYTE PTR [edx + ebx - 1], '\'
	je isSlashed
	jmp callMyDir

	; deleting the slash / antislash
	isSlashed:
	mov BYTE PTR [edx + ebx - 1], 0
	
	callMyDir:
	; invoke myDir, hEditDir, path
	push path
	push hEditDir
	call myDir
	
	; invoke PostMessage, hWindow, WM_FINISH_THREAD, NULL, NULL
	push NULL
	push NULL
	push WM_FINISH_THREAD
	push hWindow
	call PostMessage
	ret
threadHandler endp

;========================================================================================
; myDir function                                                                        ;
;========================================================================================
;
; Own implementation of the powershell command dir
; It has similiar behavior except that it is recursive, all sub-folder are explored
;
; INPUT: 	pathNotFormated = path of the folder to explore
;
; OUTPUT: 	eax = 0 if the folder has been successfully explored, 1 otherwise
myDir proc handle:HWND, pathNotFormated:DWORD

	LOCAL 	findFileData:WIN32_FIND_DATA
	LOCAL 	hFind:HANDLE
	LOCAL 	pathFormated[MAX_PATH]:byte
	LOCAL 	cptFilesForCurrentFolder[64]:byte
	
	; Regex to catch all entries into the current folder 
	; invoke wsprintf, ADDR pathFormated, ADDR WSPRINTF_SLASHED_ASTERISK_FORMATED_PATH, pathNotFormated
	push pathNotFormated
	push OFFSET WSPRINTF_SLASHED_ASTERISK_FORMATED_PATH
	lea ebx, pathFormated
	push ebx
	call wsprintf
	
	; invoke FindFirstFile, ADDR pathFormated, ADDR findFileData
	lea ebx, findFileData
	push ebx
	lea ebx, pathFormated
	push ebx
	call FindFirstFile
	
	mov hFind, eax
	cmp hFind, INVALID_HANDLE_VALUE
	jne notInvalidHandleValue
	
	; invoke wsprintf, ADDR buffer, ADDR WSPRINTF_PATH_NOT_FOUND, ADDR pathFormated
	lea ebx, pathFormated
	push ebx
	push OFFSET WSPRINTF_PATH_NOT_FOUND
	push OFFSET buffer
	call wsprintf
	
	; invoke appendTextToElement, handle, ADDR buffer
	push OFFSET buffer
	push handle
	call appendTextToElement
	and eax, eax
	jmp endListing
	
	; the first file (FindFirstFile) has been handled  correctly
	notInvalidHandleValue:
	; invoke wsprintf, ADDR buffer, ADDR WSPRINTF_LISTING_FOLDER, pathNotFormated
	push pathNotFormated
	push OFFSET WSPRINTF_LISTING_FOLDER
	push OFFSET buffer
	call wsprintf
	
	; invoke appendTextToElement, handle, ADDR buffer
	push OFFSET buffer
	push handle
	call appendTextToElement
	
	mov cptFilesForCurrentFolder, 0

	; label for printing the current file data
	printingFileData:
	inc cptFilesForCurrentFolder
	
	; invoke wsprintf, ADDR buffer, ADDR WSPRINTF_CPT_FILE, cptFilesForCurrentFolder
	push 0
	mov al, cptFilesForCurrentFolder
	movzx ax, al
	push ax
	push OFFSET WSPRINTF_CPT_FILE
	push OFFSET buffer
	call wsprintf
	
	; invoke appendTextToElement, handle, ADDR buffer
	push OFFSET buffer
	push handle
	call appendTextToElement
	
	invoke printDateTime, handle, findFileData.ftCreationTime
	; push DWORD PTR findFileData.ftCreationTime
	; push handle
	; call printDateTime
	
	mov edx, findFileData.dwFileAttributes
	and edx, FILE_ATTRIBUTE_DIRECTORY
	cmp edx, 0
	je isFile
	
	; the current entry is a folder
	; invoke wsprintf, ADDR buffer, ADDR WSPRINTF_REP, ADDR findFileData.cFileName
	lea eax, findFileData.cFileName
	push eax
	push OFFSET WSPRINTF_REP
	push OFFSET buffer
	call wsprintf
	add ESP,0Ch

	; invoke appendTextToElement, handle, ADDR buffer
	push OFFSET buffer
	push handle
	call appendTextToElement

	; tests for checking if the entry is one of the "." or ".." symbolic link
	; invoke strCompare, ADDR findFileData.cFileName, ADDR STRING_DOT
	push OFFSET STRING_DOT
	lea eax, findFileData.cFileName
	push eax
	call strCompare
	cmp eax, 0
	je continueListing

	; invoke strCompare, ADDR findFileData.cFileName, ADDR STRING_DOTDOT
	push OFFSET STRING_DOTDOT
	lea eax, findFileData.cFileName
	push eax
	call strCompare
	cmp eax, 0
	je continueListing

	; invoke wsprintf, ADDR pathFormated, ADDR WSPRINTF_SLASHED_NEXT_FOLDER, pathNotFormated, ADDR findFileData.cFileName
	lea eax, findFileData.cFileName
	push eax
	push DWORD PTR pathNotFormated
	push OFFSET WSPRINTF_SLASHED_NEXT_FOLDER
	lea eax, pathFormated
	push eax
	call wsprintf
	add ESP, 010h
	
	; the entry is a folder and not "." or ".." we recursively call the function to explore the current entry
	; invoke myDir, hEditDir, ADDR pathFormated
	lea eax, pathFormated
	push eax
	push hEditDir
	call myDir
	
	; the entry has been explored we can end the exploring of the parent entry
	; invoke wsprintf, ADDR buffer, ADDR WSPRINTF_CONTINUE_LISTING_FOLDER, pathNotFormated
	push DWORD PTR pathNotFormated
	push OFFSET WSPRINTF_CONTINUE_LISTING_FOLDER
	push OFFSET buffer
	call wsprintf
	add ESP, 0Ch
	
	; invoke appendTextToElement, handle, ADDR buffer
	push OFFSET buffer
	push handle
	call appendTextToElement

	; Entry folder has been treated, go no the next entry
	jmp continueListing
	
	; The current entry is a file
	isFile:
	; invoke wsprintf, ADDR buffer, ADDR WSPRINTF_NOT_REP, ADDR findFileData.cFileName
	lea eax, findFileData.cFileName
	push eax
	push OFFSET WSPRINTF_NOT_REP
	push OFFSET buffer
	call wsprintf
	add ESP, 0Ch

	; invoke appendTextToElement, handle, ADDR buffer
	push OFFSET buffer
	push handle
	call appendTextToElement

	; get the next entry
	continueListing:
	; invoke FindNextFile, hFind, ADDR findFileData
	lea eax, findFileData
	push eax
	push hFind
	call FindNextFile
	
	; The current entry has been fully explored
	cmp eax, 0
	je end_listing
	; Otherwise go to the beginning of the loop to treat the new entry
	jmp printingFileData
	end_listing:
	; invoke wsprintf, ADDR buffer, ADDR WSPRINTF_FINISHING_LISTING_FOLDER, pathNotFormated
	push DWORD PTR pathNotFormated
	push OFFSET WSPRINTF_FINISHING_LISTING_FOLDER
	push OFFSET buffer
	call wsprintf
	add ESP, 0Ch
	
	; invoke appendTextToElement, handle, ADDR buffer
	push OFFSET buffer
	push handle
	call appendTextToElement
	
	endListing:
	; invoke FindClose, hFind
	push hFind
	call FindClose
	ret

myDir endp

;========================================================================================
; appendTextToElement function                                                          ;
;========================================================================================
;
; Append text to a graphical element
;
; INPUT:	handle = Handle of the graphical element where the function append the text
;			text = text append to the graphical element
;
; OUTPUT: 	No meaningful values returned
appendTextToElement proc handle:HWND, text:DWORD
	
	LOCAL 	wParam:WPARAM
	LOCAL 	lParam:LPARAM

	; invoke GetWindowTextLength, handle
	push handle
	call GetWindowTextLength
	mov wParam, eax
	mov lParam, eax

	; invoke SetFocus, hWnd
	push handle
	call SetFocus

	; invoke SendMessage, hWnd, EM_SETSEL, wParam, lParam
	push lParam
	push wParam
	push EM_SETSEL
	push handle
	call SendMessage

	; invoke SendMessage, hWnd, EM_REPLACESEL, 0, text
	push text
	push 0
	push EM_REPLACESEL
	push handle
	call SendMessage

	ret
	
appendTextToElement endp

;========================================================================================
; printDateTime function                                                              ;
;========================================================================================
;
; Append text to a graphical element
;
; INPUT: 	handle = Handle of the graphical element where the function append the text
;
; OUTPUT: 	No meaningful values returned
printDateTime proc handle:HWND, ft:FILETIME

	LOCAL 	systemTime:SYSTEMTIME
	LOCAL 	localDate[255]:byte
	LOCAL 	localTime[255]:byte

	; invoke FileTimeToLocalFileTime, ADDR ft, ADDR ft
	lea ebx, ft
	push ebx
	push ebx
	call FileTimeToLocalFileTime

	; invoke FileTimeToSystemTime, ADDR ft, ADDR systemTime
	lea ebx, systemTime
	push ebx
	lea ebx, ft
	push ebx
	call FileTimeToSystemTime

	; invoke GetDateFormat, LOCALE_USER_DEFAULT, DATE_SHORTDATE, ADDR systemTime, NULL,  ADDR localDate, 255
	push 255
	lea ebx, localDate
	push ebx
	push NULL
	lea ebx, systemTime
	push ebx
	push DATE_SHORTDATE
	push LOCALE_USER_DEFAULT
	call GetDateFormat

	; invoke GetTimeFormat, LOCALE_USER_DEFAULT, 0, ADDR systemTime, NULL, ADDR localTime, 255
	push 255
	lea ebx, localTime
	push ebx
	push NULL
	lea ebx, systemTime
	push ebx
	push 0
	push LOCALE_USER_DEFAULT
	call GetTimeFormat

	; invoke appendTextToElement, handle, ADDR localDate
	lea ebx, localDate
	push ebx
	push handle
	call appendTextToElement

	; invoke appendTextToElement, handle, ADDR STRING_SPACE
	lea ebx, STRING_SPACE
	push ebx
	push handle
	call appendTextToElement
	
	; invoke appendTextToElement, handle, ADDR localTime
	lea ebx, localTime
	push ebx
	push handle
	call appendTextToElement

	ret
	
printDateTime endp

;========================================================================================
; strCompare function                                                                   ;
;========================================================================================
;
; Compare two strings
;
; INPUT: 	str1 = first string to compare
;		 	str2 = second string to compare
;
; OUTPUT: 	eax = 0 if equals, 1 otherwise
strCompare proc str1:DWORD, str2:DWORD

	mov ebx, str1
	mov edx, str2

	compareCurrentChar:
	mov al, [ebx]
	mov ah, [edx]
	cmp  al, ah
	je isEqual

	and eax, eax
	jmp compareEnd

	isEqual:
	cmp  al, 0
	je compareEqual
	inc ebx
	inc edx
	jmp compareCurrentChar

	compareEqual:
	xor  eax, eax
	
	compareEnd:
	ret 
	
strCompare endp

start:
	; invoke GetModuleHandle, NULL
	push NULL
	call  GetModuleHandle

	mov	hInstance, eax

	; invoke WinMain, hInstance
	push hInstance
	call WinMain

	; invoke ExitProcess,eax
	push eax
	call ExitProcess
end start