/***************************************************************************************************
** fpga_nes/sw/src/scriptmgrdlg.cpp
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
*  Test script dialog implementation.
***************************************************************************************************/

#include "nesdbg.h"
#include "resource.h"
#include "scriptmgr.h"

/***************************************************************************************************
** % Method:      ScriptMgr::TestScriptDlgProc()
*  % Description: Test script launcher dialog proc callback implementation.
*  % Returns:     TRUE if message was handled, FALSE otherwise.
***************************************************************************************************/
BOOL CALLBACK ScriptMgr::TestScriptDlgProc(
    HWND   hWndDlg,  // handle to the dialog box
    UINT   msg,      // message
    WPARAM wParam,   // message-specific information
    LPARAM lParam)   // additional message-specific information
{
    ScriptMgr* pScriptMgr = g_pNesDbg->GetScriptMgr();

    BOOL ret = TRUE;

    switch (msg)
    {
        case WM_INITDIALOG:
            pScriptMgr->m_hWndDlg = hWndDlg;
            pScriptMgr->TestScriptDlgInit();
            break;
        case WM_COMMAND:
            switch (LOWORD(wParam))
            {
                case IDC_TESTSCRIPTS_RUN:
                    pScriptMgr->TestScriptDlgRun();
                    break;
                case IDC_TESTSCRIPTS_CLEAR:
                    SendDlgItemMessage(hWndDlg, IDC_TESTSCRIPTS_OUTPUT, WM_SETTEXT, 0, (LPARAM)_T(""));
                    break;
                case IDC_TESTSCRIPTS_DONE:
                case IDCANCEL:
                    pScriptMgr->m_hWndDlg = NULL;
                    EndDialog(hWndDlg, wParam);
                    break;
            }
            break;
        default:
            ret = FALSE;
            break;
    }

    return ret;
}

/***************************************************************************************************
** % Method:      ScriptMgr::TestScriptDlgInit()
*  % Description: Initialize TestScript dialog - called on WM_INITDIALOG message.
*  % Returns:     N/A
***************************************************************************************************/
VOID ScriptMgr::TestScriptDlgInit()
{
    assert(m_hWndDlg);

    //
    // Populate the test list box with all *.lua files in the test script folder.
    //
    const TCHAR* pScriptDir           = GetScriptDir();
    const TCHAR* pScriptFileFilter    = _T("*.lua");
    const UINT   scriptPathFilterSize = _tcslen(pScriptDir) + _tcslen(pScriptFileFilter) + 1;

    TCHAR* pScriptPathFilter = new TCHAR [scriptPathFilterSize];
    assert(pScriptPathFilter);

    _tcscpy_s(pScriptPathFilter, scriptPathFilterSize, pScriptDir);
    _tcscat_s(pScriptPathFilter, scriptPathFilterSize, pScriptFileFilter);

    SendDlgItemMessage(m_hWndDlg, IDC_TESTSCRIPTS_LIST, LB_DIR, 0, (LPARAM)pScriptPathFilter);

    delete [] pScriptPathFilter;
}

/***************************************************************************************************
** % Method:      ScriptMgr::TestScriptDlgRun()
*  % Description: Handles click of the TestScript dialog "Run" button.
*  % Returns:     N/A
***************************************************************************************************/
VOID ScriptMgr::TestScriptDlgRun()
{
    assert(m_hWndDlg);

    const TCHAR* pScriptDir = GetScriptDir();

    // Get the number of selected items in the script list.
    const UINT scriptCnt = SendDlgItemMessage(m_hWndDlg,
                                              IDC_TESTSCRIPTS_LIST,
                                              LB_GETSELCOUNT,
                                              0,
                                              0);

    if (scriptCnt == 0)
    {
        MessageBox(NULL, _T("No tests selected."), m_pNesDbg->GetMessageBoxTitle(), 0);
        return;
    }

    // Get an index list of all selected scripts.
    INT* pScriptIndices = new INT[scriptCnt];
    assert(pScriptIndices);

    SendDlgItemMessage(m_hWndDlg,
                       IDC_TESTSCRIPTS_LIST,
                       LB_GETSELITEMS,
                       (WPARAM)scriptCnt,
                       (LPARAM)pScriptIndices);

    UINT passCnt  = 0;
    UINT failCnt  = 0;
    UINT errorCnt = 0;

    TestScriptDlgSetResults(0, 0, 0);

    // Execute all selected scripts.
    for (UINT i = 0; i < scriptCnt; i++)
    {
        TestScriptDlgSetProgress(i, scriptCnt);

        //
        // Extract the current test's full path.
        //
        const UINT fileNameLen = SendDlgItemMessage(m_hWndDlg,
                                                    IDC_TESTSCRIPTS_LIST,
                                                    LB_GETTEXTLEN,
                                                    (WPARAM)pScriptIndices[i],
                                                    0);

        const UINT filePathLen = _tcslen(pScriptDir) + fileNameLen + 1;
        TCHAR* pFilePath = new TCHAR[filePathLen];
        assert(pFilePath);
        _tcscpy_s(pFilePath, filePathLen, pScriptDir);

        TCHAR* pFileName = pFilePath + _tcslen(pScriptDir);
        SendDlgItemMessage(m_hWndDlg,
                           IDC_TESTSCRIPTS_LIST,
                           LB_GETTEXT,
                           (WPARAM)pScriptIndices[i],
                           (LPARAM)pFileName);

        static TCHAR* pStartTestFmt = _T("====== %s ========================\r\n");
        TestScriptDlgAppendOutput(pStartTestFmt, pFileName);
        ScriptResult result = ExecuteScript(pFilePath);

        static TCHAR* pEndTestFmt = _T("====== Result: %s\r\n\r\n");
        static const TCHAR* scriptResultStrTbl[] = { _T("PASS"), _T("FAIL"), _T("ERROR") };
        TestScriptDlgAppendOutput(pEndTestFmt, scriptResultStrTbl[result]);

        if (result == SCRIPT_RESULT_PASS)
        {
            passCnt++;
        }
        else if (result == SCRIPT_RESULT_FAIL)
        {
            failCnt++;
        }
        else
        {
            assert(result == SCRIPT_RESULT_ERROR);
            errorCnt++;
        }

        TestScriptDlgSetResults(passCnt, failCnt, errorCnt);

        delete [] pFilePath;
    }

    TestScriptDlgSetProgress(scriptCnt, scriptCnt);

    delete [] pScriptIndices;
}

/***************************************************************************************************
** % Method:      ScriptMgr::TestScriptDlgSetProgress()
*  % Description: Sets current progress (% of tests complete) in dialog text and progress bar.
*  % Returns:     N/A
***************************************************************************************************/
VOID ScriptMgr::TestScriptDlgSetProgress(
    UINT testsDone,  // number of tests completed
    UINT testCnt)    // total number of tests
{
    assert(m_hWndDlg);
    assert(testsDone <= testCnt);

    // Update progress text.
    static const UINT ProgressBufSize = 128;
    TCHAR progressString[ProgressBufSize];
    _stprintf_s(&progressString[0], ProgressBufSize, _T("Progress: %d / %d"), testsDone, testCnt);

    SendDlgItemMessage(m_hWndDlg,
                       IDC_TESTSCRIPTS_PROGRESSTXT,
                       WM_SETTEXT,
                       0,
                       (LPARAM)&progressString[0]);

    // Update progress bar.
    PBRANGE pbRange;
    SendDlgItemMessage(m_hWndDlg,
                       IDC_TESTSCRIPTS_PROGRESS,
                       PBM_GETRANGE,
                       0,
                       (LPARAM)&pbRange);

    FLOAT pctDone = static_cast<FLOAT>(testsDone) / static_cast<FLOAT>(testCnt);
    INT   pos     = static_cast<INT>(((pbRange.iHigh - pbRange.iLow) * pctDone) + pbRange.iLow);

    SendDlgItemMessage(m_hWndDlg,
                       IDC_TESTSCRIPTS_PROGRESS,
                       PBM_SETPOS,
                       (WPARAM)pos,
                       0);
}

/***************************************************************************************************
** % Method:      ScriptMgr::TestScriptDlgSetResults()
*  % Description: Updates current results tally, Pass/Fail/Error.
*  % Returns:     N/A
***************************************************************************************************/
VOID ScriptMgr::TestScriptDlgSetResults(
    UINT passCnt,   // number of passing tests
    UINT failCnt,   // number of failing tests
    UINT errorCnt)  // number of tests with errors
{
    static const UINT ResultsBufSize = 128;
    TCHAR resultsString[ResultsBufSize];
    _stprintf_s(&resultsString[0],
                ResultsBufSize,
                _T("Results: %d Pass / %d Fail / %d Error"),
                passCnt,
                failCnt,
                errorCnt);

    SendDlgItemMessage(m_hWndDlg,
                       IDC_TESTSCRIPTS_RESULTSTXT,
                       WM_SETTEXT,
                       0,
                       (LPARAM)&resultsString[0]);
}

/***************************************************************************************************
** % Method:      ScriptMgr::TestScriptDlgAppendOutput()
*  % Description: Appends the specified string to the output display of the test script dialog.
*  % Returns:     N/A
***************************************************************************************************/
VOID ScriptMgr::TestScriptDlgAppendOutput(
    const TCHAR* pFmtText,  // format string for output
    ...)                    // var args
{
    assert(m_hWndDlg);

    static const UINT TmpBufSize = 1024;
    TCHAR tmpBuf[TmpBufSize];

    va_list argList;

    va_start(argList, pFmtText);
    _vstprintf_s(&tmpBuf[0], TmpBufSize, pFmtText, argList);
    va_end(argList);

    // Set the current "selection" to be at the max position and 0 size.  This lets the subsequent
    // EM_REPLACESEL message act as an append operation.
    SendDlgItemMessage(m_hWndDlg,
                       IDC_TESTSCRIPTS_OUTPUT,
                       EM_SETSEL,
                       (WPARAM)MAXINT,
                       (LPARAM)MAXINT);
    SendDlgItemMessage(m_hWndDlg,
                       IDC_TESTSCRIPTS_OUTPUT,
                       EM_REPLACESEL,
                       0,
                       (LPARAM)&tmpBuf[0]);
}

