/***************************************************************************************************
** fpga_nes/sw/src/nesdbg.h
*
*  Copyright (c) 2012, Brian Bennett
*  All rights reserved.
*
*  Redistribution and use in source and binary forms, with or without modification, are permitted
*  provided that the following conditions are met:
*
*  1. Redistributions of source code must retain the above copyright notice, this list of conditions
*     and the following disclaimer.
*  2. Redistributions in binary form must reproduce the above copyright notice, this list of
*     conditions and the following disclaimer in the documentation and/or other materials provided
*     with the distribution.
*
*  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
*  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
*  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
*  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
*  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
*  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
*  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
*  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*
*  NesDbg class header.
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
    static BOOL CALLBACK RomLoadProgressDlgProc(
        HWND   hWndDlg,
        UINT   msg,
        WPARAM wParam,
        LPARAM lParam);

    HINSTANCE   m_hInstance;        // handle to application instance
    HWND        m_hWnd;             // handle to main application window

    HFONT       m_hFontCourierNew;  // handle to the "Courier New" fixed-width font

    SerialComm* m_pSerialComm;      // serial communication manager
    ScriptMgr*  m_pScriptMgr;       // script manager
};

extern NesDbg* g_pNesDbg;

#endif // NESDBG_H

