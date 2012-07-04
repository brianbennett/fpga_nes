/***************************************************************************************************
** fpga_nes/sw/src/scriptmgr.h
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
*  ScriptMgr class header.
***************************************************************************************************/

#ifndef SCRIPTMGR_H
#define SCRIPTMGR_H

#include "nesdbg.h"

struct lua_State;

/***************************************************************************************************
** % Enum:        ScriptResult
*  % Description: Conveys result of script execution.
***************************************************************************************************/
enum ScriptResult
{
    SCRIPT_RESULT_PASS,
    SCRIPT_RESULT_FAIL,
    SCRIPT_RESULT_ERROR
};

/***************************************************************************************************
** % Class:       ScriptMgr
*  % Description: Manages lua test script capabilities.
***************************************************************************************************/
class ScriptMgr
{
public:
    explicit ScriptMgr(NesDbg* pNesDbg);
    ~ScriptMgr();

    BOOL Init();

    static BOOL CALLBACK TestScriptDlgProc(HWND hWndDlg, UINT msg, WPARAM wParam, LPARAM lParam);

private:
    ScriptMgr& operator=(const ScriptMgr&);
    ScriptMgr(const ScriptMgr&);

    // TODO: Allow user configurable script directory.
    static const TCHAR* __pScriptDir;
    static const TCHAR* GetScriptDir() { return __pScriptDir; }

    // TODO: Allow user configurable prg directory.
    static const TCHAR* __pAsmPrgDir;
    static const TCHAR* GetAsmPrgDir() { return __pAsmPrgDir; }

    ScriptResult ExecuteScript(const TCHAR* pFilePath);

    VOID TestScriptDlgInit();
    VOID TestScriptDlgRun();
    VOID TestScriptDlgSetProgress(UINT testsDone, UINT testCnt);
    VOID TestScriptDlgSetResults(UINT passCnt, UINT failCnt, UINT errorCnt);
    VOID TestScriptDlgAppendOutput(const TCHAR* pFmtText, ...);

    // Lua/C functions
    static INT LuaPrint(lua_State* pLuaVm);
    static INT LuaEcho(lua_State* pLuaVm);
    static INT LuaCpuMemRd(lua_State* pLuaVm);
    static INT LuaCpuMemWr(lua_State* pLuaVm);
    static INT LuaDbgHlt(lua_State* pLuaVm);
    static INT LuaDbgRun(lua_State* pLuaVm);
    static INT LuaCpuRegRd(lua_State* pLuaVm);
    static INT LuaCpuRegWr(lua_State* pLuaVm);
    static INT LuaWaitForHlt(lua_State* pLuaVm);
    static INT LuaLoadAsm(lua_State* pLuaVm);
    static INT LuaPpuMemRd(lua_State* pLuaVm);
    static INT LuaPpuMemWr(lua_State* pLuaVm);

    NesDbg*      m_pNesDbg;  // NesDbg object that owns this ScriptMgr object
    lua_State*   m_pLuaVm;   // lua virtual machine

    HWND         m_hWndDlg;  // HWND for the test script dialog box
};

#endif // SCRIPTMGR_H

