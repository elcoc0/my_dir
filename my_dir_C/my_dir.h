/*******************************************************************************
 *
 * File Name         : my_dir.h
 * Created By        : elcoc0
 * Creation Date     : September 30th, 2015
 * Last Change       : November  8th, 2015 at 11:17:27 PM
 * Last Changed By   : elcoc0
 * Purpose           : Own implementation of the dir function (PowerShell)
 *
 *******************************************************************************/

#ifndef MY_DIR_HEADER_
#define MY_DIR_HEADER_

	#define ID_BUTTON_LAUNCH 1
	#define ID_BUTTON_CLEAR 2
	#define ID_BUTTON_EXIT 3
	#define ID_EDIT_LABEL 4
	#define ID_EDIT_PATH 5
	#define ID_EDIT_DIR 6

	int WINAPI WinMain (HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow);
	LRESULT CALLBACK WindowProcedure (HWND, UINT, WPARAM, LPARAM);
	int myDir(const HWND handle, const char *pathNotFormated);
	void printDataForCurrentFile(const HWND handle, WIN32_FIND_DATA *findFileData, char *formatedPath, const char *pathNotFormated, int *cptFilesForCurrentFolder);
	void appendTextToElement(const HWND handle, const char *text);
	void printDateTime(const HWND handle, FILETIME ft);
	BOOL GetFolderSelection(HWND handle, LPTSTR buffer, LPCTSTR title);

#endif
