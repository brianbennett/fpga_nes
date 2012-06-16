/***************************************************************************************************
** % File:        scriptmgr.h
*  % Description: ScriptMgr class header.
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
    static INT LuaDbgBrk(lua_State* pLuaVm);
    static INT LuaDbgRun(lua_State* pLuaVm);
    static INT LuaCpuRegRd(lua_State* pLuaVm);
    static INT LuaCpuRegWr(lua_State* pLuaVm);
    static INT LuaWaitForBrk(lua_State* pLuaVm);
    static INT LuaLoadAsm(lua_State* pLuaVm);
    static INT LuaPpuMemRd(lua_State* pLuaVm);
    static INT LuaPpuMemWr(lua_State* pLuaVm);

    NesDbg*      m_pNesDbg;  // NesDbg object that owns this ScriptMgr object
    lua_State*   m_pLuaVm;   // lua virtual machine

    HWND         m_hWndDlg;  // HWND for the test script dialog box
};

#endif // SCRIPTMGR_H

