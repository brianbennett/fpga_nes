/***************************************************************************************************
** fpga_nes/sw/src/main.cpp
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
*  NesDbg application main implementation.
***************************************************************************************************/

#include "nesdbg.h"
#include "resource.h"

NesDbg* g_pNesDbg = NULL;

/***************************************************************************************************
** % Function:    WndProc()
*  % Description: Window message handling callback.
***************************************************************************************************/
static LRESULT CALLBACK WndProc(
    HWND   hWnd,    // window handle
    UINT   msg,     // message id
    WPARAM wParam,  // additional message info
    LPARAM lParam)  // additional message info
{
    LRESULT ret = 0;

    switch (msg)
    {
        case WM_COMMAND:
            switch (LOWORD(wParam))
            {
                case IDM_FILE_EXIT:
                    PostMessage(hWnd, WM_CLOSE, 0, 0);
                    break;
                case IDM_FILE_LOADROM:
                    g_pNesDbg->LoadRom();
                    break;
                case IDM_TOOLS_RAWDEBUG:
                    g_pNesDbg->LaunchRawDbgDlg();
                    break;
                case IDM_TOOLS_TESTSCRIPTS:
                    g_pNesDbg->LaunchTestScriptDlg();
                    break;
            }
            break;
        case WM_DESTROY:
            PostQuitMessage(0);
            break;
        default:
            ret = DefWindowProc(hWnd, msg, wParam, lParam);
            break;
    }

    return ret;
}

/***************************************************************************************************
** % Function:    WinMain()
*  % Description: Program entry-point.
***************************************************************************************************/
INT WINAPI WinMain(
    HINSTANCE hInstance,      // handle to current application instance
    HINSTANCE hPrevInstance,  // handle to previous application instance
    LPSTR     pCmdLine,       // command line string, excluding program name
    INT       cmdShow)        // controls how window should be shown
{
    WNDCLASSEX wcex    = {0};
    HWND       hWnd    = NULL;
    INT        ret     = 0;
    BOOL       success = TRUE;

    static TCHAR* pWndClassName = _T("nesdbg");
    static TCHAR* pWndTitle     = _T("FPGA NES Debugger");

    wcex.cbSize         = sizeof(WNDCLASSEX);
    wcex.style          = CS_HREDRAW | CS_VREDRAW;
    wcex.lpfnWndProc    = WndProc;
    wcex.cbClsExtra     = 0;
    wcex.cbWndExtra     = 0;
    wcex.hInstance      = hInstance;
    wcex.hIcon          = NULL;
    wcex.hCursor        = LoadCursor(NULL, IDC_ARROW);
    wcex.hbrBackground  = reinterpret_cast<HBRUSH>(COLOR_WINDOW);
    wcex.lpszMenuName   = _T("MainMenu");
    wcex.lpszClassName  = pWndClassName;
    wcex.hIconSm        = NULL;

    if (!RegisterClassEx(&wcex))
    {
        MessageBox(NULL, _T("RegisterClassEx failed."), pWndTitle, NULL);
        success = FALSE;
    }

    if (success)
    {
        hWnd = CreateWindow(pWndClassName,
                            pWndTitle,
                            WS_OVERLAPPEDWINDOW,
                            CW_USEDEFAULT,
                            CW_USEDEFAULT,
                            640,
                            480,
                            NULL,
                            NULL,
                            hInstance,
                            NULL);

        if (!hWnd)
        {
            MessageBox(NULL, _T("CreateWindow failed."), pWndTitle, NULL);
            success = FALSE;
        }
    }

    if (success)
    {
        g_pNesDbg = new NesDbg(hInstance, hWnd);
        if (!g_pNesDbg || !g_pNesDbg->Init())
        {
            success = FALSE;
        }
    }

    if (success)
    {
        ShowWindow(hWnd, cmdShow);
        UpdateWindow(hWnd);

        MSG msg;
        while (GetMessage(&msg, NULL, 0, 0))
        {
            TranslateMessage(&msg);
            DispatchMessage(&msg);
        }

        ret = static_cast<INT>(msg.wParam);
    }

    delete g_pNesDbg;
    g_pNesDbg = NULL;

    return ret;
}

