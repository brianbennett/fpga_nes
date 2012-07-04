/***************************************************************************************************
** fpga_nes/sw/src/scriptmgr.cpp
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
*  ScriptMgr class implementation.
***************************************************************************************************/

#include <lua.hpp>

#include "dbgpacket.h"
#include "nesdbg.h"
#include "resource.h"
#include "scriptmgr.h"
#include "serialcomm.h"

const TCHAR* ScriptMgr::__pScriptDir = _T("../scripts/");
const TCHAR* ScriptMgr::__pAsmPrgDir = _T("../asm/prg/");

/***************************************************************************************************
** % Method:      ScriptMgr::ScriptMgr()
*  % Description: ScriptMgr constructor.
***************************************************************************************************/
ScriptMgr::ScriptMgr(
    NesDbg* pNesDbg)  // NesDbg object that is creating this script manager
    :
    m_pNesDbg(pNesDbg)
{
}

/***************************************************************************************************
** % Method:      ScriptMgr::~ScriptMgr()
*  % Description: ScriptMgr destructor.
***************************************************************************************************/
ScriptMgr::~ScriptMgr()
{
    if (m_pLuaVm)
    {
        lua_close(m_pLuaVm);
    }
}

/***************************************************************************************************
** % Method:      ScriptMgr::Init()
*  % Description: ScriptMgr initialization method.  Must be called before any other method.
*  % Returns:     TRUE on success, FALSE otherwise.
***************************************************************************************************/
BOOL ScriptMgr::Init()
{
    BOOL ret = TRUE;

    // Initialize lua virtual machine.
    if (ret)
    {
        m_pLuaVm = lua_open();

        ret = (m_pLuaVm) ? TRUE : FALSE;
    }

    // Open necessary libraries.
    if (ret)
    {
        luaopen_base(m_pLuaVm);
        luaopen_math(m_pLuaVm);
    }

    // Register lua/C functions.
    if (ret)
    {
        // Overload print to output to the test script dialog box.
        lua_pushcfunction(m_pLuaVm, LuaPrint);
        lua_setglobal(m_pLuaVm, "print");

        // Register the nesdbg set of functions as the "nesdbg" library.
        static const struct luaL_Reg nesDbgLib[] =
        {
            { "Echo",        LuaEcho        },
            { "CpuMemRd",    LuaCpuMemRd    },
            { "CpuMemWr",    LuaCpuMemWr    },
            { "DbgHlt",      LuaDbgHlt      },
            { "DbgRun",      LuaDbgRun      },
            { "CpuRegRd",    LuaCpuRegRd    },
            { "CpuRegWr",    LuaCpuRegWr    },
            { "WaitForHlt",  LuaWaitForHlt  },
            { "LoadAsm",     LuaLoadAsm     },
            { "PpuMemRd",    LuaPpuMemRd    },
            { "PpuMemWr",    LuaPpuMemWr    },
            { NULL,          NULL           }
        };

        luaL_register(m_pLuaVm, "nesdbg", nesDbgLib);
    }

    return ret;
}

/***************************************************************************************************
** % Method:      ScriptMgr::ExecuteScript()
*  % Description: Execute the script in the specified file.
*  % Returns:     Script's result: pass, fail, error.
***************************************************************************************************/
ScriptResult ScriptMgr::ExecuteScript(
    const TCHAR* pFilePath)  // full path/filename for script to be run
{
    ScriptResult ret = SCRIPT_RESULT_ERROR;

    const CHAR* pAsciiFilePath = CreateAsciiString(pFilePath);
    INT luaRet = luaL_dofile(g_pNesDbg->GetScriptMgr()->m_pLuaVm, pAsciiFilePath);

    if (luaRet == 0)
    {
        ret = static_cast<ScriptResult>(static_cast<UINT>(lua_tonumber(m_pLuaVm, -1)));
    }
    else
    {
        ret = SCRIPT_RESULT_ERROR;

        const TCHAR* pErrString = CreateTcharString(lua_tostring(m_pLuaVm, -1));
        TestScriptDlgAppendOutput(_T("%s\r\n"), pErrString);
        DestroyTcharString(pErrString);
    }

    DestroyAsciiString(pAsciiFilePath);

    return ret;
}

/***************************************************************************************************
** % Method:      ScriptMgr::LuaPrint()
*  % Description: Overload standard lua print with a version that outputs to the test script dialog
*                 box.
*  % Returns:     Number of values returned to lua.  (0)
***************************************************************************************************/
INT ScriptMgr::LuaPrint(
    lua_State* pLuaVm)  // lua state
{
    ScriptMgr* pScriptMgr = g_pNesDbg->GetScriptMgr();

    // Usage: print(input [string])
    if (!lua_isstring(pLuaVm, 1))
    {
        assert(0);
        return 0;
    }

    const TCHAR* pString = CreateTcharString(lua_tostring(pLuaVm, 1));
    pScriptMgr->TestScriptDlgAppendOutput(pString);
    DestroyTcharString(pString);

    return 0;
}

/***************************************************************************************************
** % Method:      ScriptMgr::LuaEcho()
*  % Description: Issues a echo debug packet to the FPGA and returns an array with the result data.
*  % Returns:     Number of values returned to lua.  (1)
***************************************************************************************************/
INT ScriptMgr::LuaEcho(
    lua_State* pLuaVm)  // lua state
{
    // Usage: [table] Echo(numBytes [number], inData [table])
    if (!lua_isnumber(pLuaVm, 1) || !lua_istable(pLuaVm, 2))
    {
        assert(0);
        return 0;
    }

    // Read the number of echo bytes from arg 1, and allocate memory on the heap to store it.
    USHORT numBytes = static_cast<USHORT>(lua_tonumber(pLuaVm, 1));
    BYTE* pEchoData = new BYTE [numBytes];
    assert(pEchoData);

    // Copy the array from arg 2 into pEchoData.
    for (UINT i = 1; i <= numBytes; i++)
    {
        lua_rawgeti(pLuaVm, 2, i);
        pEchoData[i - 1] = static_cast<UINT>(lua_tonumber(pLuaVm, -1));
        lua_pop(pLuaVm, 1);
    }

    // Create an echo packet, and issue it to the FPGA.
    EchoPacket echoPacket(pEchoData, numBytes);
    g_pNesDbg->GetSerialComm()->SendData(echoPacket.PacketData(), echoPacket.SizeInBytes());

    // Allocate space to receive the FPGA returned data.
    UINT bytesToReceive = echoPacket.ReturnBytesExpected();
    BYTE* pReceivedData = new BYTE[bytesToReceive];
    assert(pReceivedData);

    // Read data back from the FPGA.
    g_pNesDbg->GetSerialComm()->ReceiveData(pReceivedData, bytesToReceive);

    // Push the return data into a return table.
    lua_newtable(pLuaVm);
    for (UINT i = 0; i < bytesToReceive; i++)
    {
        lua_pushnumber(pLuaVm, i + 1);
        lua_pushnumber(pLuaVm, pReceivedData[i]);
        lua_settable(pLuaVm, -3);
    }

    delete [] pReceivedData;
    delete [] pEchoData;

    return 1;
}

/***************************************************************************************************
** % Method:      ScriptMgr::LuaCpuMemRd()
*  % Description: Issues a CpuMemRd debug packet to the FPGA and returns an array with the result
*                 data.
*  % Returns:     Number of values returned to lua.  (1)
***************************************************************************************************/
INT ScriptMgr::LuaCpuMemRd(
    lua_State* pLuaVm)  // lua state
{
    // Usage: [table] CpuMemRd(address [number], numBytes [number])
    if (!lua_isnumber(pLuaVm, 1) || !lua_isnumber(pLuaVm, 2))
    {
        assert(0);
        return 0;
    }

    USHORT addr     = static_cast<USHORT>(lua_tonumber(pLuaVm, 1));
    USHORT numBytes = static_cast<USHORT>(lua_tonumber(pLuaVm, 2));

    // Create a cpu memory read packet, and issue it to the FPGA.
    CpuMemRdPacket cpuMemRdPacket(addr, numBytes);
    g_pNesDbg->GetSerialComm()->SendData(cpuMemRdPacket.PacketData(), cpuMemRdPacket.SizeInBytes());

    // Allocate space to receive the FPGA returned data.
    UINT bytesToReceive = cpuMemRdPacket.ReturnBytesExpected();
    BYTE* pReceivedData = new BYTE[bytesToReceive];
    assert(pReceivedData);

    // Read data back from the FPGA.
    g_pNesDbg->GetSerialComm()->ReceiveData(pReceivedData, bytesToReceive);

    // Push the return data into a return table.
    lua_newtable(pLuaVm);
    for (UINT i = 0; i < bytesToReceive; i++)
    {
        lua_pushnumber(pLuaVm, i + 1);
        lua_pushnumber(pLuaVm, pReceivedData[i]);
        lua_settable(pLuaVm, -3);
    }

    delete [] pReceivedData;

    return 1;
}

/***************************************************************************************************
** % Method:      ScriptMgr::LuaCpuMemWr()
*  % Description: Issues a CpuMemWr debug packet to the FPGA and returns an array with the result
*                 data.
*  % Returns:     Number of values returned to lua.  (0)
***************************************************************************************************/
INT ScriptMgr::LuaCpuMemWr(
    lua_State* pLuaVm)  // lua state
{
    // Usage: CpuMemWr(address [number], numBytes [number], data [table])
    if (!lua_isnumber(pLuaVm, 1) || !lua_isnumber(pLuaVm, 2)  || !lua_istable(pLuaVm, 3))
    {
        assert(0);
        return 0;
    }

    USHORT addr     = static_cast<USHORT>(lua_tonumber(pLuaVm, 1));
    USHORT numBytes = static_cast<USHORT>(lua_tonumber(pLuaVm, 2));

    // Allocate memory on the heap to store a copy of the lua data table.
    BYTE* pData = new BYTE [numBytes];
    assert(pData);

    // Copy the array from arg 2 into pEchoData.
    for (UINT i = 1; i <= numBytes; i++)
    {
        lua_rawgeti(pLuaVm, 3, i);
        pData[i - 1] = static_cast<UINT>(lua_tonumber(pLuaVm, -1));
        lua_pop(pLuaVm, 1);
    }

    // Create a cpu memory write packet, and issue it to the FPGA.
    CpuMemWrPacket cpuMemWrPacket(addr, numBytes, pData);
    g_pNesDbg->GetSerialComm()->SendData(cpuMemWrPacket.PacketData(), cpuMemWrPacket.SizeInBytes());

    assert(cpuMemWrPacket.ReturnBytesExpected() == 0);

    delete [] pData;

    return 0;
}

/***************************************************************************************************
** % Method:      ScriptMgr::LuaDbgHlt()
*  % Description: Issues a DbgHlt debug packet to the FPGA, halting its execution and allowing it
*                 to interact with the debugger.
*  % Returns:     Number of values returned to lua.  (0)
***************************************************************************************************/
INT ScriptMgr::LuaDbgHlt(
    lua_State* pLuaVm)  // lua state
{
    DbgHltPacket dbgHltPacket;
    g_pNesDbg->GetSerialComm()->SendData(dbgHltPacket.PacketData(), dbgHltPacket.SizeInBytes());

    return 0;
}

/***************************************************************************************************
** % Method:      ScriptMgr::LuaDbgRun()
*  % Description: Issues a DbgRun debug packet to the FPGA, resuming its execution after a DbgHlt.
*  % Returns:     Number of values returned to lua.  (0)
***************************************************************************************************/
INT ScriptMgr::LuaDbgRun(
    lua_State* pLuaVm)  // lua state
{
    DbgRunPacket dbgRunPacket;
    g_pNesDbg->GetSerialComm()->SendData(dbgRunPacket.PacketData(), dbgRunPacket.SizeInBytes());

    return 0;
}

/***************************************************************************************************
** % Method:      ScriptMgr::LuaCpuRegRd()
*  % Description: Issues a CpuRegRd debug packet to the FPGA and returns the register data.
*  % Returns:     Number of values returned to lua.  (1)
***************************************************************************************************/
INT ScriptMgr::LuaCpuRegRd(
    lua_State* pLuaVm)  // lua state
{
    // Usage: [number] CpuRegRd(regSel [number])
    if (!lua_isnumber(pLuaVm, 1))
    {
        assert(0);
        return 0;
    }

    CpuReg regSel = static_cast<CpuReg>(static_cast<UINT>((lua_tonumber(pLuaVm, 1))));

    // Create a cpu memory read packet, and issue it to the FPGA.
    CpuRegRdPacket cpuRegRdPacket(regSel);
    g_pNesDbg->GetSerialComm()->SendData(cpuRegRdPacket.PacketData(), cpuRegRdPacket.SizeInBytes());

    // Allocate space to receive the FPGA returned data.
    UINT bytesToReceive = cpuRegRdPacket.ReturnBytesExpected();
    BYTE* pReceivedData = new BYTE[bytesToReceive];
    assert(pReceivedData);

    // Read data back from the FPGA.
    g_pNesDbg->GetSerialComm()->ReceiveData(pReceivedData, bytesToReceive);

    // Push the return data.
    lua_pushinteger(pLuaVm, *pReceivedData);

    delete [] pReceivedData;

    return 1;
}

/***************************************************************************************************
** % Method:      ScriptMgr::LuaCpuRegWr()
*  % Description: Issues a CpuRegWr debug packet to the FPGA.
*  % Returns:     Number of values returned to lua.  (0)
***************************************************************************************************/
INT ScriptMgr::LuaCpuRegWr(
    lua_State* pLuaVm)  // lua state
{
    // Usage: CpuRegWr(regSel [number], val [number])
    if (!lua_isnumber(pLuaVm, 1) || !lua_isnumber(pLuaVm, 2))
    {
        assert(0);
        return 0;
    }

    CpuReg regSel = static_cast<CpuReg>(static_cast<UINT>((lua_tonumber(pLuaVm, 1))));
    BYTE   val    = static_cast<BYTE>(lua_tonumber(pLuaVm, 2));

    // Create a cpu memory read packet, and issue it to the FPGA.
    CpuRegWrPacket cpuRegWrPacket(regSel, val);
    g_pNesDbg->GetSerialComm()->SendData(cpuRegWrPacket.PacketData(), cpuRegWrPacket.SizeInBytes());

    assert(cpuRegWrPacket.ReturnBytesExpected() == 0);
    return 0;
}

/***************************************************************************************************
** % Method:      ScriptMgr::LuaWaitForHlt()
*  % Description: Returns control to the lua script once the NES CPU is halted.
*  % Returns:     Number of values returned to lua.  (0)
***************************************************************************************************/
INT ScriptMgr::LuaWaitForHlt(
    lua_State* pLuaVm)  // lua state
{
    // Create a debug break query packet, and issue it to the FPGA until we detect a debug break.
    QueryHltPacket queryDbgHltPacket;

    // Allocate space to receive the FPGA returned data.
    UINT bytesToReceive = queryDbgHltPacket.ReturnBytesExpected();
    assert(bytesToReceive == 1);
    BYTE* pReceivedData = new BYTE[bytesToReceive];
    assert(pReceivedData);

    do
    {
        g_pNesDbg->GetSerialComm()->SendData(queryDbgHltPacket.PacketData(),
                                             queryDbgHltPacket.SizeInBytes());
        g_pNesDbg->GetSerialComm()->ReceiveData(pReceivedData, bytesToReceive);

        Sleep(10);
    } while (*pReceivedData == 0);

    delete [] pReceivedData;

    return 0;
}

/***************************************************************************************************
** % Method:      ScriptMgr::LuaLoadAsm()
*  % Description: Loads an assembled .prg file from an external file.
*  % Returns:     Number of values returned to lua.  (1)
***************************************************************************************************/
INT ScriptMgr::LuaLoadAsm(
    lua_State* pLuaVm)  // lua state
{
    // Usage: [number] LoadAsm(input [string])
    if (!lua_isstring(pLuaVm, 1))
    {
        assert(0);
        return 0;
    }

    const TCHAR* pAsmPrgDir  = GetAsmPrgDir();
    const TCHAR* pFileName   = CreateTcharString(lua_tostring(pLuaVm, 1));
    const UINT   filePathLen = _tcslen(pAsmPrgDir) + _tcslen(pFileName) + 1;
    TCHAR* pFilePath         = new TCHAR[filePathLen];

    _tcscpy_s(pFilePath, filePathLen, pAsmPrgDir);
    _tcscat_s(pFilePath, filePathLen, pFileName);

    HANDLE hPrgFile = CreateFile(pFilePath,
                                 GENERIC_READ,
                                 0,
                                 NULL,
                                 OPEN_EXISTING,
                                 FILE_ATTRIBUTE_NORMAL,
                                 NULL);
    USHORT startPc = 0;

    if (hPrgFile != INVALID_HANDLE_VALUE)
    {
        static const UINT FileDataBufferSize = 0x10000;

        BYTE* pFileData = new BYTE[FileDataBufferSize];
        DWORD fileDataActualSize = 0;

        if (ReadFile(hPrgFile, pFileData, FileDataBufferSize, &fileDataActualSize, NULL))
        {
            startPc = pFileData[0] | (pFileData[1] << 8);

            // Create a cpu memory write packet, and issue it to the FPGA.
            CpuMemWrPacket cpuMemWrPacket(startPc,
                                          (USHORT)(fileDataActualSize - 2),
                                          &pFileData[2]);
            g_pNesDbg->GetSerialComm()->SendData(cpuMemWrPacket.PacketData(),
                                                 cpuMemWrPacket.SizeInBytes());

            assert(cpuMemWrPacket.ReturnBytesExpected() == 0);
        }
        else
        {
            MessageBox(NULL, _T("Failed to read data from .prg file."), _T("NesDbg"), MB_OK);
        }

        delete [] pFileData;
        CloseHandle(hPrgFile);
    }
    else
    {
        MessageBox(NULL, _T("Failed to open .prg file."), _T("NesDbg"), MB_OK);
    }

    DestroyTcharString(pFileName);
    delete [] pFilePath;

    // Push the return data.
    lua_pushinteger(pLuaVm, startPc);

    return 1;
}

/***************************************************************************************************
** % Method:      ScriptMgr::LuaPpuMemRd()
*  % Description: Issues a PpuMemRd debug packet to the FPGA and returns an array with the result
*                 data.
*  % Returns:     Number of values returned to lua.  (1)
***************************************************************************************************/
INT ScriptMgr::LuaPpuMemRd(
    lua_State* pLuaVm)  // lua state
{
    // Usage: [table] PpuMemRd(address [number], numBytes [number])
    if (!lua_isnumber(pLuaVm, 1) || !lua_isnumber(pLuaVm, 2))
    {
        assert(0);
        return 0;
    }

    USHORT addr     = static_cast<USHORT>(lua_tonumber(pLuaVm, 1));
    USHORT numBytes = static_cast<USHORT>(lua_tonumber(pLuaVm, 2));

    // Create a ppu memory read packet, and issue it to the FPGA.
    PpuMemRdPacket ppuMemRdPacket(addr, numBytes);
    g_pNesDbg->GetSerialComm()->SendData(ppuMemRdPacket.PacketData(), ppuMemRdPacket.SizeInBytes());

    // Allocate space to receive the FPGA returned data.
    UINT bytesToReceive = ppuMemRdPacket.ReturnBytesExpected();
    BYTE* pReceivedData = new BYTE[bytesToReceive];
    assert(pReceivedData);

    // Read data back from the FPGA.
    g_pNesDbg->GetSerialComm()->ReceiveData(pReceivedData, bytesToReceive);

    // Push the return data into a return table.
    lua_newtable(pLuaVm);
    for (UINT i = 0; i < bytesToReceive; i++)
    {
        lua_pushnumber(pLuaVm, i + 1);
        lua_pushnumber(pLuaVm, pReceivedData[i]);
        lua_settable(pLuaVm, -3);
    }

    delete [] pReceivedData;

    return 1;
}

/***************************************************************************************************
** % Method:      ScriptMgr::LuaPpuMemWr()
*  % Description: Issues a PpuMemWr debug packet to the FPGA and returns an array with the result
*                 data.
*  % Returns:     Number of values returned to lua.  (0)
***************************************************************************************************/
INT ScriptMgr::LuaPpuMemWr(
    lua_State* pLuaVm)  // lua state
{
    // Usage: PpuMemWr(address [number], numBytes [number], data [table])
    if (!lua_isnumber(pLuaVm, 1) || !lua_isnumber(pLuaVm, 2)  || !lua_istable(pLuaVm, 3))
    {
        assert(0);
        return 0;
    }

    USHORT addr     = static_cast<USHORT>(lua_tonumber(pLuaVm, 1));
    USHORT numBytes = static_cast<USHORT>(lua_tonumber(pLuaVm, 2));

    // Allocate memory on the heap to store a copy of the lua data table.
    BYTE* pData = new BYTE [numBytes];
    assert(pData);

    // Copy the array from arg 2 into pEchoData.
    for (UINT i = 1; i <= numBytes; i++)
    {
        lua_rawgeti(pLuaVm, 3, i);
        pData[i - 1] = static_cast<UINT>(lua_tonumber(pLuaVm, -1));
        lua_pop(pLuaVm, 1);
    }

    // Create a ppu memory write packet, and issue it to the FPGA.
    PpuMemWrPacket ppuMemWrPacket(addr, numBytes, pData);
    g_pNesDbg->GetSerialComm()->SendData(ppuMemWrPacket.PacketData(), ppuMemWrPacket.SizeInBytes());

    assert(ppuMemWrPacket.ReturnBytesExpected() == 0);

    delete [] pData;

    return 0;
}

