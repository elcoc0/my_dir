/*******************************************************************************
 *
 * File Name         : my_dir.c
 * Created By        : elcoc0
 * Creation Date     : September 30th, 2015
 * Last Change       : November  8th, 2015 at 11:17:27 PM
 * Last Changed By   : elcoc0
 * Purpose           : Own implementation of the dir function (PowerShell)
 *
 *******************************************************************************/

#include <tchar.h>
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <shlobj.h>
#include <objbase.h>
#include "my_dir.h"

//  Make the class name into a global variable
TCHAR szClassName[ ] = _T("SimpleWinClass");
TCHAR path[MAX_PATH];

static HINSTANCE ghInstance = NULL;
static HWND hEditLabel, hButtonLaunch, hButtonExit, hButtonClear, hEditPath, hEditDir;

/**
 * WinMain function
 * Create the window empty and  loop for  dispatching messages event
 * @param hInstance : handle to the current instance of the application.
 * @param hPrevInstance : handle to the previous instance of the application
 * @param lpCmdLine : server port number
 * @param nCmdShow : controls how the window is to be shown
 * @return If the function succeeds, terminating when it receives a WM_QUIT message, it should return the exit value contained in that message's wParam parameter.
 * 		   If the function terminates before entering the message loop, it should return zero.
 * @see For more information check the windows API documentation
 */
int WINAPI WinMain (HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
	HWND hwnd;               // This is the handle for our window
	MSG messages;            // Here messages to the application are saved
	WNDCLASSEX wincl;        // Data structure for the windowclass

	// The Window structure
	wincl.hInstance = hInstance;
	wincl.lpszClassName = szClassName;
	wincl.lpfnWndProc = WindowProcedure;      // This function is called by windows
	wincl.style = CS_DBLCLKS;                 // Catch double-clicks
	wincl.cbSize = sizeof (WNDCLASSEX);

	// Use default icon and mouse-pointer
	wincl.hIcon = LoadIcon (NULL, IDI_APPLICATION);
	wincl.hIconSm = LoadIcon (NULL, IDI_APPLICATION);
	wincl.hCursor = LoadCursor (NULL, IDC_ARROW);
	wincl.lpszMenuName = NULL;                 // No menu
	wincl.cbClsExtra = 0;                      // No extra bytes after the window class
	wincl.cbWndExtra = 0;                      // structure or the window instance
	// Use Windows's default colour as the background of the window
	wincl.hbrBackground = (HBRUSH)COLOR_BACKGROUND;

	// Register the window class, and if it fails quit the program
	if (!RegisterClassEx (&wincl))
		return 0;

	// The class is registered, let's create the program
	hwnd = CreateWindowEx (
			0,                   // Extended possibilites for variation
			szClassName,         // Classname
			_T("My dir PowerShell CMD (Coded in C)"),       // Title Text
			WS_OVERLAPPEDWINDOW, // default window
			CW_USEDEFAULT,       // Windows decides the position
			CW_USEDEFAULT,       // where the window ends up on the screen
			800,                 // The programs width
			600,                 // and height in pixels
			HWND_DESKTOP,        // The window is a child-window to desktop
			NULL,                // No menu
			hInstance,       // Program Instance handler
			NULL                 // No Window Creation data
	);

	if (hwnd == NULL) {
		MessageBox(NULL, "Window Creation Failed!", "Error!",
				MB_ICONEXCLAMATION | MB_OK);
		return 0;
	}


	// Make the window visible on the screen
	ShowWindow (hwnd, nCmdShow);
	UpdateWindow(hwnd);
	// Run the message loop. It will run until GetMessage() returns 0
	while (GetMessage (&messages, NULL, 0, 0)) {
		// Translate virtual-key messages into character messages
		TranslateMessage(&messages);
		// Send message to WindowProcedure
		DispatchMessage(&messages);
	}

	// The program return-value is 0 - The value that PostQuitMessage() gave
	return messages.wParam;
}

/**
 * WindowProcedure function
 * This function is called when messages are dispatched
 * @see Windows#DispatchMessage(lpmsg)
 * @see For more information check the windows API documentation
 */
LRESULT CALLBACK WindowProcedure (HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam)
{
	//switch WM events
	switch (message)
	{

	// The window has been successfully created, now we create all the components of the windows
	case WM_CREATE:
		hEditLabel   = CreateWindowEx(
				0,
				"Edit",
				"Enter a correct folder path : ",
				WS_CHILD | WS_VISIBLE | ES_READONLY,
				20, 10,
				250, 30,
				hwnd, (HMENU) ID_EDIT_LABEL,
				ghInstance,
				NULL);

		hEditPath   = CreateWindowEx(
				0,
				"Static",
				"",
				WS_TABSTOP | WS_BORDER | WS_CHILD | WS_VISIBLE | SS_NOTIFY,
				20, 50,
				380, 30,
				hwnd, (HMENU) ID_EDIT_PATH,
				ghInstance,
				NULL);
		hButtonLaunch = CreateWindowEx(
				0,
				"Button",
				"LAUNCH",
				WS_TABSTOP | WS_BORDER | WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
				420, 50,
				100, 30,
				hwnd, (HMENU) ID_BUTTON_LAUNCH,
				ghInstance,
				NULL);
		hButtonClear = CreateWindowEx(
				0,
				"Button",
				"CLEAR",
				WS_BORDER | WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
				540, 50,
				100, 30,
				hwnd, (HMENU) ID_BUTTON_CLEAR,
				ghInstance,
				NULL);
		hButtonExit = CreateWindowEx(
				0,
				"Button",
				"EXIT",
				WS_BORDER | WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
				660, 50,
				100, 30,
				hwnd, (HMENU) ID_BUTTON_EXIT,
				ghInstance,
				NULL);
		hEditDir = CreateWindowEx(
				0,
				"Edit",
				"",
				WS_BORDER | WS_CHILD | WS_VISIBLE | ES_READONLY | ES_MULTILINE | ES_AUTOVSCROLL | ES_AUTOHSCROLL |  WS_VSCROLL | WS_HSCROLL,
				20, 100,
				740, 450,
				hwnd, (HMENU) ID_EDIT_DIR,
				ghInstance,
				NULL);
		// The max value of the interactive console graphical component (hEditDir)
		SendMessage(hEditDir, EM_SETLIMITTEXT, 0xFFFFFFFF, 0);
		break;
	// The window has received a command
	case WM_COMMAND:
	{
		if (HIWORD(wParam) == BN_CLICKED || HIWORD(wParam) ==  STN_CLICKED) {
			switch LOWORD(wParam) {
			// Pop the dialog box to let the user select a folder
			case  ID_EDIT_PATH:
				GetFolderSelection(hwnd, path, NULL);
				SetDlgItemText(hwnd,ID_EDIT_PATH, path);
				break;
			// Launch myDir function
			case ID_BUTTON_LAUNCH:
				GetDlgItemText(hwnd, ID_EDIT_PATH, path, MAX_PATH);
				appendTextToElement(hEditDir, "\r\nExecuting my DIR function (recursively)\r\n");
				myDir(hEditDir, (char *) path);
				break;
			// Clear edit text
			case ID_BUTTON_CLEAR:
				SetWindowText(hEditDir, (LPSTR) "");
				SetWindowText(hEditPath, (LPSTR) "");
				break;
			case ID_BUTTON_EXIT:
				DestroyWindow(hwnd);
				break;
			default:
				break;
			}
		}
	}
	break;
	// The window has been closed
	case WM_CLOSE:
		DestroyWindow(hwnd);
		break;
	// The window has ben destroyed
	case WM_DESTROY:
		PostQuitMessage (0);       // send a WM_QUIT to the message queue
		break;
	default:                      // for messages that we don't deal with
		return DefWindowProc (hwnd, message, wParam, lParam);
	}
	return 0;
}

/**
 * listFilesDir function
 * Recursive function for exploring a folder and its sub folders
 * @param path_not_formated : path of the folder to explore
 * @param handle : component where to print the data folder
 * @return 0 if the folder has been successfully explored, 1 otherwise
 */
int myDir(const HWND handle, const char *pathNotFormated)
{
	WIN32_FIND_DATA findFileData;
	HANDLE hFind;
	char formatedPath[4096];
	char buffer[4096];
	int cptFilesForCurrentFolder = 0;

	// Regex to catch all entries into the current folder
	sprintf(formatedPath, "%s/*", pathNotFormated);
	// Initialize the findFileData by calling the method FindFirstFile
	hFind = FindFirstFile(formatedPath, &findFileData);

	// Error handling
	if (hFind == INVALID_HANDLE_VALUE) {
		sprintf(buffer, "Path not found: [%s]\r\n", formatedPath);
		appendTextToElement(handle, buffer);
		return 1;
	}
	sprintf(buffer, "\r\nListing content of folder: %s\r\n", pathNotFormated);
	appendTextToElement(handle, buffer);
	printDataForCurrentFile(handle, &findFileData, formatedPath, pathNotFormated, &cptFilesForCurrentFolder);

	// While loop for all entries in the current folder
	while (FindNextFile(hFind, &findFileData)) {
		printDataForCurrentFile(handle, &findFileData, formatedPath, pathNotFormated, &cptFilesForCurrentFolder);
	}
	sprintf(buffer, "\r\nThe folder %s has been listed successfully\r\n", pathNotFormated);
	appendTextToElement(handle, buffer);
	FindClose(hFind);
	return 0;
}
/**
 * printDataForCurrentFile function
 * This function is called from the myDir function, it is used for printing all the information about the current entry
 * @param handle
 * @param findFileData
 * @param formatedPath
 * @param pathNotFormated
 * @param cptFilesForCurrentFolder
 * @see my_dir.c#myDir
 */
void printDataForCurrentFile(const HWND handle, WIN32_FIND_DATA *findFileData, char *formatedPath, const char *pathNotFormated, int *cptFilesForCurrentFolder)
{
	char buffer[4096];

	// Listing current data entry
	sprintf(buffer, "File [%d]: ", ++*cptFilesForCurrentFolder);
	appendTextToElement(handle, buffer);
	printDateTime(handle, findFileData->ftCreationTime);

	// If the entry is a folder
	if (findFileData->dwFileAttributes &FILE_ATTRIBUTE_DIRECTORY) {
		sprintf(buffer, "  <REP>  %s\r\n", findFileData->cFileName);
		appendTextToElement(handle, buffer);

		// If the folder is not the symbolic link "." or ".."
		// Then call myDir to print the entries of the current folder
		if(strcmp(findFileData->cFileName, ".") != 0 && strcmp(findFileData->cFileName, "..") != 0) {
			sprintf(formatedPath, "%s/%s", pathNotFormated, findFileData->cFileName);
			myDir(handle, formatedPath);
			sprintf(buffer, "\r\nContinue listing content of folder : %s\r\n", pathNotFormated);
			appendTextToElement(handle, buffer);
		}
	} else {
		sprintf(buffer, "               %s\r\n", findFileData->cFileName);
		appendTextToElement(handle, buffer);
	}
}

/**
 * appendTextToElement function
 * Append text to a graphical element
 * @param  	hansdle : Handle of the graphical element where the function append the text
 * @param  	text : text append to the graphical element
 */
void appendTextToElement(const HWND handle, const char *text)
{
	int length = GetWindowTextLength (handle);
	SetFocus (handle);
	SendMessage (handle, EM_SETSEL, (WPARAM)length, (LPARAM)length);
	SendMessage (handle, EM_REPLACESEL, 0, (LPARAM) ((LPSTR) text));
}

/**
 * printDateTime function
 * Print the date and the time of the filetime into a graphical element
 * @param handle : handle of the graphical element
 * @param ft : filetime where are stored the date and time to display
 */
void printDateTime(const HWND handle, FILETIME ft)
{
	SYSTEMTIME st;
	char localDate[255], localTime[255];

	FileTimeToLocalFileTime( &ft, &ft );
	FileTimeToSystemTime( &ft, &st );
	GetDateFormat( LOCALE_USER_DEFAULT, DATE_SHORTDATE, &st, NULL, localDate, 255 );
	GetTimeFormat( LOCALE_USER_DEFAULT, 0, &st, NULL, localTime, 255 );
	appendTextToElement(handle, localDate);
	appendTextToElement(handle, " ");
	appendTextToElement(handle, localTime);
}

/**
 * GetFolderSelection function
 * Function for letting the user chose a folder thanks to a dialog box
 * @param handle : handle of the parent window
 * @param buffer : buffer where to store the returning path of the folder
 * @param title : title of the dialog box
 * @return : 0 if a folder has been selected, 1 otherwise
 */
BOOL GetFolderSelection(HWND handle, LPTSTR buffer, LPCTSTR title)
{
	LPITEMIDLIST pidl     = NULL;
	BROWSEINFO   bi       = { 0 };
	BOOL         bResult  = FALSE;

	bi.hwndOwner      = handle;
	bi.pszDisplayName = buffer;
	bi.pidlRoot       = NULL;
	bi.lpszTitle      = title;
	bi.ulFlags        = BIF_RETURNONLYFSDIRS | BIF_USENEWUI;

	if ((pidl = SHBrowseForFolder(&bi)) != NULL) {
		bResult = SHGetPathFromIDList(pidl, buffer);
	}

	return bResult;
}
