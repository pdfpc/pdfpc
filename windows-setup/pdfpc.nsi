; pdfpc NSIS installation script for Windows
; Original Authors: The Xournal++ Team (https://github.com/xournalpp/xournalpp/)
; Adapted for pdfpc: malex14

;--------------------------------
; NSIS setup

Unicode true

;--------------------------------
; Includes

!include "MUI2.nsh"
!include x64.nsh
!include "FileAssociation.nsh"
!include nsDialogs.nsh
!include "pdfpc_version.nsh"

;--------------------------------
; Initialization

Function .onInit
	${If} ${RunningX64}
		# 64 bit code
		SetRegView 64
	${Else}
		# 32 bit code
		MessageBox MB_OK "pdfpc requires 64-bit Windows. Sorry!"
		Abort
	${EndIf}
FunctionEnd

; Name and file
Name "pdfpc ${PDFPC_VERSION}"
OutFile "pdfpc-setup.exe"

; Default installation folder
InstallDir $PROGRAMFILES64\pdfpc

; Get installation folder from registry if available
InstallDirRegKey HKLM "Software\pdfpc" ""

; Request admin privileges for installation
RequestExecutionLevel admin

;--------------------------------
; Variables

Var StartMenuFolder

;--------------------------------
; Interface Settings

!define MUI_ABORTWARNING

;--------------------------------
; Pages
!insertmacro MUI_PAGE_WELCOME
;Page custom InstallScopePage InstallScopePageLeave
!insertmacro MUI_PAGE_LICENSE "..\LICENSE.txt"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY

;Start Menu Folder Page Configuration
!define MUI_STARTMENUPAGE_REGISTRY_ROOT "HKLM"
!define MUI_STARTMENUPAGE_REGISTRY_KEY "Software\pdfpc"
!define MUI_STARTMENUPAGE_REGISTRY_VALUENAME "StartMenuEntry"
!define MUI_STARTMENUPAGE_DEFAULTFOLDER "pdfpc"

!insertmacro MUI_PAGE_STARTMENU Application $StartMenuFolder

!insertmacro MUI_PAGE_INSTFILES

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

;--------------------------------
; Languages

!insertmacro MUI_LANGUAGE "English"

;-------------------------------
; Uninstall previous version

Section "" SecUninstallPrevious
	ReadRegStr $R0 HKLM "Software\pdfpc" ""
	${If} $R0 != ""
        DetailPrint "Removing previous version located at $R0"
		ExecWait '"$R0\Uninstall.exe /S"' 
    ${EndIf}
SectionEnd

;-------------------------------
; File association macros
; see https://docs.microsoft.com/en-us/windows/win32/shell/fa-file-types#registering-a-file-type

!macro SetDefaultExt EXT PROGID
	WriteRegStr HKLM "Software\Classes\${EXT}" "" "${PROGID}"
!macroend

!macro RegisterExt EXT PROGID
	WriteRegStr HKLM "Software\Classes\${EXT}\OpenWithProgIds" "${PROGID}" ""
	WriteRegStr HKLM "Software\Classes\Applications\pdfpc.exe\SupportedTypes" "${EXT}" ""
!macroend

!macro AddProgId PROGID CMD DESC
	; Define ProgId. See https://docs.microsoft.com/en-us/windows/win32/shell/fa-progids
	WriteRegStr HKLM "Software\Classes\${PROGID}" "" "${DESC}"
	WriteRegStr HKLM "Software\Classes\${PROGID}\DefaultIcon" "" '"${CMD}",0'
	WriteRegStr HKLM "Software\Classes\${PROGID}\shell" "" "open"
	WriteRegStr HKLM "Software\Classes\${PROGID}\shell\open\command" "" '"${CMD}" "%1"'
!macroend

!macro DeleteProgId PROGID
	; See https://docs.microsoft.com/en-us/windows/win32/shell/fa-file-types#deleting-registry-information-during-uninstallation
	DeleteRegKey HKLM "Software\Classes\${PROGID}"
!macroend

!define SHCNE_ASSOCCHANGED 0x08000000
!define SHCNE_CREATE 0x2
!define SHCNE_DELETE 0x4

!define SHCNF_IDLIST 0x0
!define SHCNF_PATH 0x1
!define SHCNF_FLUSH 0x1000
!macro RefreshShellIcons
	; Refresh shell icons. See https://nsis.sourceforge.io/Refresh_shell_icons
	DetailPrint "Refreshing shell file associations"
	System::Call "shell32::SHChangeNotify(i ${SHCNE_ASSOCCHANGED}, i ${SHCNF_FLUSH} | ${SHCNF_IDLIST}, i 0, i 0)"
!macroend

!macro RefreshShellIconCreate FILEPATH
	DetailPrint "Refreshing shell icon create ${FILEPATH}"
	System::Call 'shell32::SHChangeNotify(i ${SHCNE_CREATE}, i ${SHCNF_FLUSH} | ${SHCNF_PATH}, w "${FILEPATH}", i 0)'
!macroend

!macro RefreshShellIconDelete FILEPATH
	DetailPrint "Refreshing shell icon delete ${FILEPATH}"
	System::Call 'shell32::SHChangeNotify(i ${SHCNE_DELETE}, i ${SHCNF_FLUSH} | ${SHCNF_PATH}, w "${FILEPATH}", i 0)'
!macroend

;-------------------------------
; Installer Sections

Section "Associate .pdf files with pdfpc" SecFilePdf
	!insertmacro SetDefaultExt ".pdf" "pdfpc.pdf"
SectionEnd


Section "pdfpc" SecPdfpc
	; Required
	SectionIn RO

	SetOutPath "$INSTDIR"

	; Files to put into the setup
	File /r "dist\*"

	; Set install information
	WriteRegStr HKLM "Software\pdfpc" "" '$INSTDIR'

	; Set program information
	WriteRegStr HKLM "Software\Classes\Applications\pdfpc.exe" "" '"$INSTDIR\bin\pdfpc.exe"'
	WriteRegStr HKLM "Software\Classes\Applications\pdfpc.exe" "FriendlyAppName" "pdfpc"
	WriteRegExpandStr HKLM "Software\Classes\Applications\pdfpc.exe" "DefaultIcon" '"$INSTDIR\bin\pdfpc.exe",0'
	WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\App Paths\pdfpc.exe" "" '"$INSTDIR\bin\pdfpc.exe"'

	; Add file type information
	!insertmacro RegisterExt ".pdf" "pdfpc.pdf"
	push $R0
	StrCpy $R0 "$INSTDIR\bin\pdfpc.exe"
	!insertmacro AddProgId "pdfpc.pdf" "$R0" "PDF file"
	pop $R0

	; Create uninstaller
	WriteUninstaller "$INSTDIR\Uninstall.exe"
	; Add uninstall entry. See https://docs.microsoft.com/en-us/windows/win32/msi/uninstall-registry-key
	WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\pdfpc" "DisplayIcon" '"$INSTDIR\bin\pdfpc.exe"'
	WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\pdfpc" "DisplayName" "pdfpc"
	WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\pdfpc" "DisplayVersion" "${PDFPC_VERSION}"
	WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\pdfpc" "Publisher" "The pdfpc Team"
	WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\pdfpc" "URLInfoAbout" "https://pdfpc.github.io"
	WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\pdfpc" "InstallLocation" '"$INSTDIR"'
	WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\pdfpc" "UninstallString" '"$INSTDIR\Uninstall.exe"'
	WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\pdfpc" "NoModify" 1
	WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\pdfpc" "NoRepair" 1

	!insertmacro MUI_STARTMENU_WRITE_BEGIN Application
	;Create shortcuts
	CreateDirectory "$SMPROGRAMS\$StartMenuFolder"
	CreateShortcut "$SMPROGRAMS\$StartMenuFolder\pdfpc.lnk" '"$INSTDIR\bin\pdfpc.exe"'
	CreateShortcut "$SMPROGRAMS\$StartMenuFolder\Uninstall.lnk" '"$INSTDIR\Uninstall.exe"'
		
	!insertmacro RefreshShellIconCreate "$SMPROGRAMS\$StartMenuFolder\pdfpc.lnk"
	!insertmacro RefreshShellIconCreate "$SMPROGRAMS\$StartMenuFolder\Uninstall.lnk"
	!insertmacro MUI_STARTMENU_WRITE_END

	!insertmacro RefreshShellIcons
SectionEnd

;--------------------------------
; Descriptions

; Language strings
LangString DESC_SecPdfpc ${LANG_ENGLISH} "pdfpc executable"
LangString DESC_SecFilePdf ${LANG_ENGLISH} "Open .pdf files with pdfpc"

; Assign language strings to sections
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
	!insertmacro MUI_DESCRIPTION_TEXT ${SecPdfpc} $(DESC_SecPdfpc)
	!insertmacro MUI_DESCRIPTION_TEXT ${SecFilePdf} $(DESC_SecFilePdf)
!insertmacro MUI_FUNCTION_DESCRIPTION_END

;--------------------------------
; Uninstaller

Section "Uninstall"

	SetRegView 64

	; Remove registry keys
	DeleteRegKey HKLM "Software\pdfpc"
	DeleteRegKey HKLM "Software\Classes\Applications\pdfpc.exe"
	DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\App Paths\pdfpc.exe"
	DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\pdfpc"

	!insertmacro DeleteProgId "pdfpc.pdf"

	; Clean up start menu
	!insertmacro MUI_STARTMENU_GETFOLDER Application $StartMenuFolder
	Delete "$SMPROGRAMS\$StartMenuFolder\pdfpc.lnk"
	Delete "$SMPROGRAMS\$StartMenuFolder\Uninstall.lnk"
	RMDir "$SMPROGRAMS\$StartMenuFolder"

	; Remove files
	RMDir /r "$INSTDIR\bin"
	RMDir /r "$INSTDIR\lib"
	RMDir /r "$INSTDIR\share"
	RMDir /r "$INSTDIR\etc"
	Delete "$INSTDIR\Uninstall.exe"
	RMDir "$INSTDIR"

	!insertmacro RefreshShellIconDelete "$SMPROGRAMS\$StartMenuFolder\pdfpc.lnk"
	!insertmacro RefreshShellIconDelete "$SMPROGRAMS\$StartMenuFolder\Uninstall.lnk"
	!insertmacro RefreshShellIcons
SectionEnd
