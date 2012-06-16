/***************************************************************************************************
** % File:        nesdbg.h
*  % Description: NesDbg class header.
***************************************************************************************************/
#ifndef NESDBG_H
#define NESDBG_H

#include <windows.h>
#include <commctrl.h>
#include <tchar.h>

#include "util.h"

class ScriptMgr;
class SerialComm;

/***************************************************************************************************
** % Class:       NesDbg
*  % Description: Main manager/brain.
***************************************************************************************************/
class NesDbg
{
public:
    NesDbg(HINSTANCE hInstance, HWND hWnd);
    ~NesDbg();

    BOOL Init();

    VOID LaunchRawDbgDlg();
    VOID LaunchTestScriptDlg();
    VOID LoadRom();

    ScriptMgr*  GetScriptMgr() { return m_pScriptMgr; }
    SerialComm* GetSerialComm() { return m_pSerialComm; }

    static const TCHAR* GetMessageBoxTitle();

private:
    NesDbg& operator=(const NesDbg&);
    NesDbg(const NesDbg&);

    static BOOL CALLBACK RawDbgDlgProc(HWND hWndDlg, UINT msg, WPARAM wParam, LPARAM lParam);

    HINSTANCE   m_hInstance;        // handle to application instance
    HWND        m_hWnd;             // handle to main application window

    HFONT       m_hFontCourierNew;  // handle to the "Courier New" fixed-width font

    SerialComm* m_pSerialComm;      // serial communication manager
    ScriptMgr*  m_pScriptMgr;       // script manager
};

extern NesDbg* g_pNesDbg;

#endif // NESDBG_H

