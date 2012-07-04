/***************************************************************************************************
** fpga_nes/sw/src/dbgpacket.cpp
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
*  DbgPacket class implementation.
***************************************************************************************************/

#include "dbgpacket.h"
#include "nesdbg.h"

/***************************************************************************************************
** % Method:      DbgPacket::DbgPacket()
*  % Description: DbgPacket constructor.
***************************************************************************************************/
DbgPacket::DbgPacket()
{
}

/***************************************************************************************************
** % Method:      DbgPacket::~DbgPacket()
*  % Description: DbgPacket destructor.
***************************************************************************************************/
DbgPacket::~DbgPacket()
{
    delete [] m_pData;
}

/***************************************************************************************************
** % Method:      DbgPacket::CreateObjFromString()
*  % Description: Factory method for a DbgPacket using a text string as input, as from the raw
*                 debug interface.
***************************************************************************************************/
DbgPacket* DbgPacket::CreateObjFromString(
    TCHAR* pString)  // packet content string
{
    DbgPacket* pDbgPacket = NULL;

    BOOL success   = TRUE;
    UINT stringLen = _tcslen(pString);
    UINT nibbleIdx = 0;

    BYTE* pRawData = new BYTE [stringLen / 2];

    // Convert text string (e.g., "00 0F 13 12") to raw data.
    for (UINT i = 0; i < stringLen; i++)
    {
        BYTE input  = static_cast<BYTE>(pString[i]);
        BYTE nibble = 0;

        if ((input >= '0') && (input <= '9'))
        {
            nibble = input - '0';
        }
        else if ((input >= 'a') && (input <= 'f'))
        {
            nibble = input - 'a' + 0xa;
        }
        else if ((input >= 'A') && (input <= 'F'))
        {
            nibble = input - 'A' + 0xa;
        }
        else if (input == ' ')
        {
            continue;
        }
        else
        {
            success = FALSE;
            break;
        }

        pRawData[nibbleIdx / 2] = (nibbleIdx & 1)
                                ? (pRawData[nibbleIdx / 2] | nibble)
                                : (nibble << 4);
        nibbleIdx++;
    }

    if (nibbleIdx & 1)
    {
        success = FALSE;
    }

    if (success)
    {
        switch (pRawData[0])
        {
            case DbgPacketOpCodeEcho:
            {
                const BYTE* pEchoData    = &pRawData[3];
                USHORT      numEchoBytes = *reinterpret_cast<USHORT*>(&pRawData[1]);
                pDbgPacket = new EchoPacket(pEchoData, numEchoBytes);
                break;
            }
            case DbgPacketOpCodeCpuMemRd:
            {
                USHORT addr     = *reinterpret_cast<USHORT*>(&pRawData[1]);
                USHORT numBytes = *reinterpret_cast<USHORT*>(&pRawData[3]);
                pDbgPacket = new CpuMemRdPacket(addr, numBytes);
                break;
            }
            case DbgPacketOpCodeCpuMemWr:
            {
                const BYTE* pData    = &pRawData[5];
                USHORT      addr     = *reinterpret_cast<USHORT*>(&pRawData[1]);
                USHORT      numBytes = *reinterpret_cast<USHORT*>(&pRawData[3]);
                pDbgPacket = new CpuMemWrPacket(addr, numBytes, pData);
                break;
            }
            default:
            {
                success = FALSE;
                break;
            }
        }

        delete [] pRawData;
    }

    return pDbgPacket;
}

/***************************************************************************************************
** % Method:      EchoPacket::EchoPacket()
*  % Description: EchoPacket constructor.
***************************************************************************************************/
EchoPacket::EchoPacket(
    const BYTE* pEchoData,  // data to be echoed
    USHORT      numBytes)   // number of bytes to echo
{
    m_pData = new BYTE [1 + 2 + numBytes];

    m_pData[0] = DbgPacketOpCodeEcho;

    for (UINT i = 0; i < numBytes; i++)
    {
        m_pData[3 + i] = pEchoData[i];
    }

    *reinterpret_cast<USHORT*>(&m_pData[1]) = numBytes;
}

/***************************************************************************************************
** % Method:      EchoPacket::SizeInBytes()
*  % Description: Returns total packet size, in bytes.
***************************************************************************************************/
UINT EchoPacket::SizeInBytes() const
{
    return sizeof(BYTE) + sizeof(USHORT) + *reinterpret_cast<USHORT*>(&m_pData[1]);
}

/***************************************************************************************************
** % Method:      EchoPacket::ReturnBytesExpected()
*  % Description: Returns how many bytes we expect to receive from the NES in response to this
*                 packet.
***************************************************************************************************/
UINT EchoPacket::ReturnBytesExpected() const
{
    return *reinterpret_cast<USHORT*>(&m_pData[1]);
}

/***************************************************************************************************
** % Method:      CpuMemRdPacket::CpuMemRdPacket()
*  % Description: CpuMemRdPacket constructor.
***************************************************************************************************/
CpuMemRdPacket::CpuMemRdPacket(
    USHORT addr,      // memory address to read
    USHORT numBytes)  // number of bytes to read
{
    m_pData = new BYTE [1 + 2 + 2];

    m_pData[0] = DbgPacketOpCodeCpuMemRd;
    *reinterpret_cast<USHORT*>(&m_pData[1]) = addr;
    *reinterpret_cast<USHORT*>(&m_pData[3]) = numBytes;
}

/***************************************************************************************************
** % Method:      CpuMemRdPacket::SizeInBytes()
*  % Description: Returns total packet size, in bytes.
***************************************************************************************************/
UINT CpuMemRdPacket::SizeInBytes() const
{
    return sizeof(BYTE) + sizeof(USHORT) + sizeof(USHORT);
}

/***************************************************************************************************
** % Method:      CpuMemRdPacket::ReturnBytesExpected()
*  % Description: Returns how many bytes we expect to receive from the NES in response to this
*                 packet.
***************************************************************************************************/
UINT CpuMemRdPacket::ReturnBytesExpected() const
{
    return *reinterpret_cast<USHORT*>(&m_pData[3]);
}

/***************************************************************************************************
** % Method:      CpuMemWrPacket::CpuMemWrPacket()
*  % Description: CpuMemWrPacket constructor.
***************************************************************************************************/
CpuMemWrPacket::CpuMemWrPacket(
    USHORT      addr,      // memory address to write
    USHORT      numBytes,  // number of bytes to write
    const BYTE* pData)     // data to write
{
    m_pData = new BYTE [1 + 2 + 2 + numBytes];

    m_pData[0] = DbgPacketOpCodeCpuMemWr;
    *reinterpret_cast<USHORT*>(&m_pData[1]) = addr;
    *reinterpret_cast<USHORT*>(&m_pData[3]) = numBytes;

    for (UINT i = 0; i < numBytes; i++)
    {
        m_pData[5 + i] = pData[i];
    }
}

/***************************************************************************************************
** % Method:      CpuMemWrPacket::SizeInBytes()
*  % Description: Returns total packet size, in bytes.
***************************************************************************************************/
UINT CpuMemWrPacket::SizeInBytes() const
{
    return sizeof(BYTE) + sizeof(USHORT) + sizeof(USHORT) + *reinterpret_cast<USHORT*>(&m_pData[3]);
}

/***************************************************************************************************
** % Method:      CpuMemWrPacket::ReturnBytesExpected()
*  % Description: Returns how many bytes we expect to receive from the NES in response to this
*                 packet.
***************************************************************************************************/
UINT CpuMemWrPacket::ReturnBytesExpected() const
{
    return 0;
}

/***************************************************************************************************
** % Method:      DbgHltPacket::DbgHltPacket()
*  % Description: DbgHltPacket constructor.
***************************************************************************************************/
DbgHltPacket::DbgHltPacket()
{
    m_pData    = new BYTE [1];
    m_pData[0] = DbgPacketOpCodeDbgHlt;
}

/***************************************************************************************************
** % Method:      DbgRunPacket::DbgRunPacket()
*  % Description: DbgRunPacket constructor.
***************************************************************************************************/
DbgRunPacket::DbgRunPacket()
{
    m_pData    = new BYTE [1];
    m_pData[0] = DbgPacketOpCodeDbgRun;
}

/***************************************************************************************************
** % Method:      CpuRegRdPacket::CpuRegRdPacket()
*  % Description: CpuRegRdPacket constructor.
***************************************************************************************************/
CpuRegRdPacket::CpuRegRdPacket(
    CpuReg reg)  // select which register to read
{
    m_pData = new BYTE [1 + 1];

    m_pData[0] = DbgPacketOpCodeCpuRegRd;
    m_pData[1] = static_cast<BYTE>(reg);
}

/***************************************************************************************************
** % Method:      CpuRegRdPacket::SizeInBytes()
*  % Description: Returns total packet size, in bytes.
***************************************************************************************************/
UINT CpuRegRdPacket::SizeInBytes() const
{
    return sizeof(BYTE) + sizeof(BYTE);
}

/***************************************************************************************************
** % Method:      CpuRegRdPacket::ReturnBytesExpected()
*  % Description: Returns how many bytes we expect to receive from the NES in response to this
*                 packet.
***************************************************************************************************/
UINT CpuRegRdPacket::ReturnBytesExpected() const
{
    return 1;
}

/***************************************************************************************************
** % Method:      CpuRegWrPacket::CpuRegWrPacket()
*  % Description: CpuRegWrPacket constructor.
***************************************************************************************************/
CpuRegWrPacket::CpuRegWrPacket(
    CpuReg reg,  // select which register to write
    BYTE   val)  // value to write
{
    m_pData = new BYTE [1 + 1 + 1];

    m_pData[0] = DbgPacketOpCodeCpuRegWr;
    m_pData[1] = static_cast<BYTE>(reg);
    m_pData[2] = val;
}

/***************************************************************************************************
** % Method:      CpuRegWrPacket::SizeInBytes()
*  % Description: Returns total packet size, in bytes.
***************************************************************************************************/
UINT CpuRegWrPacket::SizeInBytes() const
{
    return sizeof(BYTE) + sizeof(BYTE) + sizeof(BYTE);
}

/***************************************************************************************************
** % Method:      CpuRegWrPacket::ReturnBytesExpected()
*  % Description: Returns how many bytes we expect to receive from the NES in response to this
*                 packet.
***************************************************************************************************/
UINT CpuRegWrPacket::ReturnBytesExpected() const
{
    return 0;
}

/***************************************************************************************************
** % Method:      QueryHltPacket::QueryHltPacket()
*  % Description: QueryHltPacket constructor.
***************************************************************************************************/
QueryHltPacket::QueryHltPacket()
{
    m_pData = new BYTE [1];

    m_pData[0] = DbgPacketOpCodeQueryHlt;
}

/***************************************************************************************************
** % Method:      QueryHltPacket::SizeInBytes()
*  % Description: Returns total packet size, in bytes.
***************************************************************************************************/
UINT QueryHltPacket::SizeInBytes() const
{
    return sizeof(BYTE);
}

/***************************************************************************************************
** % Method:      QueryHltPacket::ReturnBytesExpected()
*  % Description: Returns how many bytes we expect to receive from the NES in response to this
*                 packet.
***************************************************************************************************/
UINT QueryHltPacket::ReturnBytesExpected() const
{
    return 1;
}

/***************************************************************************************************
** % Method:      PpuMemRdPacket::PpuMemRdPacket()
*  % Description: PpuMemRdPacket constructor.
***************************************************************************************************/
PpuMemRdPacket::PpuMemRdPacket(
    USHORT addr,      // memory address to read
    USHORT numBytes)  // number of bytes to read
{
    m_pData = new BYTE [1 + 2 + 2];

    m_pData[0] = DbgPacketOpCodePpuMemRd;
    *reinterpret_cast<USHORT*>(&m_pData[1]) = addr;
    *reinterpret_cast<USHORT*>(&m_pData[3]) = numBytes;
}

/***************************************************************************************************
** % Method:      PpuMemRdPacket::SizeInBytes()
*  % Description: Returns total packet size, in bytes.
***************************************************************************************************/
UINT PpuMemRdPacket::SizeInBytes() const
{
    return sizeof(BYTE) + sizeof(USHORT) + sizeof(USHORT);
}

/***************************************************************************************************
** % Method:      PpuMemRdPacket::ReturnBytesExpected()
*  % Description: Returns how many bytes we expect to receive from the NES in response to this
*                 packet.
***************************************************************************************************/
UINT PpuMemRdPacket::ReturnBytesExpected() const
{
    return *reinterpret_cast<USHORT*>(&m_pData[3]);
}

/***************************************************************************************************
** % Method:      PpuMemWrPacket::PpuMemWrPacket()
*  % Description: PpuMemWrPacket constructor.
***************************************************************************************************/
PpuMemWrPacket::PpuMemWrPacket(
    USHORT      addr,      // memory address to write
    USHORT      numBytes,  // number of bytes to write
    const BYTE* pData)     // data to write
{
    m_pData = new BYTE [1 + 2 + 2 + numBytes];

    m_pData[0] = DbgPacketOpCodePpuMemWr;
    *reinterpret_cast<USHORT*>(&m_pData[1]) = addr;
    *reinterpret_cast<USHORT*>(&m_pData[3]) = numBytes;

    for (UINT i = 0; i < numBytes; i++)
    {
        m_pData[5 + i] = pData[i];
    }
}

/***************************************************************************************************
** % Method:      PpuMemWrPacket::SizeInBytes()
*  % Description: Returns total packet size, in bytes.
***************************************************************************************************/
UINT PpuMemWrPacket::SizeInBytes() const
{
    return sizeof(BYTE) + sizeof(USHORT) + sizeof(USHORT) + *reinterpret_cast<USHORT*>(&m_pData[3]);
}

/***************************************************************************************************
** % Method:      PpuMemWrPacket::ReturnBytesExpected()
*  % Description: Returns how many bytes we expect to receive from the NES in response to this
*                 packet.
***************************************************************************************************/
UINT PpuMemWrPacket::ReturnBytesExpected() const
{
    return 0;
}

/***************************************************************************************************
** % Method:      PpuDisablePacket::PpuDisablePacket()
*  % Description: PpuDisablePacket constructor.
***************************************************************************************************/
PpuDisablePacket::PpuDisablePacket()
{
    m_pData    = new BYTE [1];
    m_pData[0] = DbgPacketOpCodePpuDisable;
}

/***************************************************************************************************
** % Method:      CartSetCfgPacket::CartSetCfgPacket()
*  % Description: CartSetCfgPacket constructor.
***************************************************************************************************/
CartSetCfgPacket::CartSetCfgPacket(
    const BYTE* pINesHeader)  // iNES header pointer (should point at byte 0)
{
    m_pData = new BYTE [1 + 5];

    m_pData[0] = DbgPacketOpCodeCartSetCfg;
    m_pData[1] = pINesHeader[4];
    m_pData[2] = pINesHeader[5];
    m_pData[3] = pINesHeader[6];
    m_pData[4] = pINesHeader[7];
    m_pData[5] = pINesHeader[8];
}

/***************************************************************************************************
** % Method:      CartSetCfgPacket::SizeInBytes()
*  % Description: Returns total packet size, in bytes.
***************************************************************************************************/
UINT CartSetCfgPacket::SizeInBytes() const
{
    return sizeof(BYTE) + (5 * sizeof(BYTE));
}
