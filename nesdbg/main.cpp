/***************************************************************************************************
** % File:        main.cpp
*  % Description: Window message handling callback.
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

