/***************************************************************************************************
** fpga_nes/sw/src/dbgpacket.h
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
*  DbgPacket class header.
***************************************************************************************************/

#ifndef DBGPACKET_H
#define DBGPACKET_H

#include <windows.h>

enum DbgPacketOpCode
{
    DbgPacketOpCodeEcho              = 0x00, // echo packet body back to debugger
    DbgPacketOpCodeCpuMemRd          = 0x01, // read CPU memory
    DbgPacketOpCodeCpuMemWr          = 0x02, // write CPU memory
    DbgPacketOpCodeDbgHlt            = 0x03, // debugger break (stop execution)
    DbgPacketOpCodeDbgRun            = 0x04, // debugger run (resume execution)
    DbgPacketOpCodeCpuRegRd          = 0x05, // read CPU register
    DbgPacketOpCodeCpuRegWr          = 0x06, // read CPU register
    DbgPacketOpCodeQueryHlt          = 0x07, // query if the cpu is currently halted
    DbgPacketOpCodeQueryErrCode      = 0x08, // query NES error code
    DbgPacketOpCodePpuMemRd          = 0x09, // read PPU memory
    DbgPacketOpCodePpuMemWr          = 0x0A, // write PPU memory
    DbgPacketOpCodePpuDisable        = 0x0B, // disable PPU
    DbgPacketOpCodeCartSetCfg        = 0x0C, // set cartridge config from iNES header
};

enum CpuReg
{
    CpuRegPcl = 0x00, // PCL: Program Counter Low
    CpuRegPch = 0x01, // PCH: Program Counter High
    CpuRegAc  = 0x02, // AC:  Accumulator reg
    CpuRegX   = 0x03, // X:   X index reg
    CpuRegY   = 0x04, // Y:   Y index reg
    CpuRegP   = 0x05, // P:   Processor Status reg
    CpuRegS   = 0x06, // S:   Stack Pointer reg
};

/***************************************************************************************************
** % Class:       DbgPacket
*  % Description: Represents messages sent to and received from the NES FPGA.
***************************************************************************************************/
class DbgPacket
{
public:
    static DbgPacket* CreateObjFromString(TCHAR* pString);
    VOID Destroy() { delete this; }

    virtual ~DbgPacket();

    virtual const BYTE* PacketData() const { return m_pData; }
    virtual UINT SizeInBytes() const = 0;
    virtual UINT ReturnBytesExpected() const = 0;

protected:
    DbgPacket();

    BYTE* m_pData;

private:
    DbgPacket& operator=(const DbgPacket&);
    DbgPacket(const DbgPacket&);
};

/***************************************************************************************************
** % Class:       EchoPacket
*  % Description: Echo debug packet.
***************************************************************************************************/
class EchoPacket : public DbgPacket
{
public:
    EchoPacket(const BYTE* pEchoData, USHORT numBytes);
    virtual ~EchoPacket() {};

    virtual UINT SizeInBytes() const;
    virtual UINT ReturnBytesExpected() const;

private:
    EchoPacket();
    EchoPacket& operator=(const EchoPacket&);
    EchoPacket(const EchoPacket&);
};

/***************************************************************************************************
** % Class:       CpuMemRdPacket
*  % Description: CPU memory read debug packet.
***************************************************************************************************/
class CpuMemRdPacket : public DbgPacket
{
public:
    CpuMemRdPacket(USHORT addr, USHORT numBytes);
    virtual ~CpuMemRdPacket() {};

    virtual UINT SizeInBytes() const;
    virtual UINT ReturnBytesExpected() const;

private:
    CpuMemRdPacket();
    CpuMemRdPacket& operator=(const CpuMemRdPacket&);
    CpuMemRdPacket(const CpuMemRdPacket&);
};

/***************************************************************************************************
** % Class:       CpuMemWrPacket
*  % Description: CPU memory write debug packet.
***************************************************************************************************/
class CpuMemWrPacket : public DbgPacket
{
public:
    CpuMemWrPacket(USHORT addr, USHORT numBytes, const BYTE* pData);
    virtual ~CpuMemWrPacket() {};

    virtual UINT SizeInBytes() const;
    virtual UINT ReturnBytesExpected() const;

private:
    CpuMemWrPacket();
    CpuMemWrPacket& operator=(const CpuMemRdPacket&);
    CpuMemWrPacket(const CpuMemRdPacket&);
};

/***************************************************************************************************
** % Class:       DbgHltPacket
*  % Description: Debug halt packet.
***************************************************************************************************/
class DbgHltPacket : public DbgPacket
{
public:
    DbgHltPacket();
    virtual ~DbgHltPacket() {};

    virtual UINT SizeInBytes() const { return 1; }
    virtual UINT ReturnBytesExpected() const { return 0; }

private:
    DbgHltPacket& operator=(const DbgHltPacket&);
    DbgHltPacket(const DbgHltPacket&);
};

/***************************************************************************************************
** % Class:       DbgRunPacket
*  % Description: Debug run debug packet.
***************************************************************************************************/
class DbgRunPacket : public DbgPacket
{
public:
    DbgRunPacket();
    virtual ~DbgRunPacket() {};

    virtual UINT SizeInBytes() const { return 1; }
    virtual UINT ReturnBytesExpected() const { return 0; }

private:
    DbgRunPacket& operator=(const DbgRunPacket&);
    DbgRunPacket(const DbgRunPacket&);
};

/***************************************************************************************************
** % Class:       CpuRegRdPacket
*  % Description: CPU register read debug packet.
***************************************************************************************************/
class CpuRegRdPacket : public DbgPacket
{
public:
    CpuRegRdPacket(CpuReg reg);
    virtual ~CpuRegRdPacket() {};

    virtual UINT SizeInBytes() const;
    virtual UINT ReturnBytesExpected() const;

private:
    CpuRegRdPacket();
    CpuRegRdPacket& operator=(const CpuRegRdPacket&);
    CpuRegRdPacket(const CpuRegRdPacket&);
};

/***************************************************************************************************
** % Class:       CpuRegWrPacket
*  % Description: CPU register write debug packet.
***************************************************************************************************/
class CpuRegWrPacket : public DbgPacket
{
public:
    CpuRegWrPacket(CpuReg reg, BYTE val);
    virtual ~CpuRegWrPacket() {};

    virtual UINT SizeInBytes() const;
    virtual UINT ReturnBytesExpected() const;

private:
    CpuRegWrPacket();
    CpuRegWrPacket& operator=(const CpuRegRdPacket&);
    CpuRegWrPacket(const CpuRegRdPacket&);
};

/***************************************************************************************************
** % Class:       QueryBltPacket
*  % Description: Debug packet to query the current cpu state (running or halted).
***************************************************************************************************/
class QueryHltPacket : public DbgPacket
{
public:
    QueryHltPacket();
    virtual ~QueryHltPacket() {};

    virtual UINT SizeInBytes() const;
    virtual UINT ReturnBytesExpected() const;

private:
    QueryHltPacket& operator=(const QueryHltPacket&);
    QueryHltPacket(const QueryHltPacket&);
};

/***************************************************************************************************
** % Class:       PpuMemRdPacket
*  % Description: PPU memory read debug packet.
***************************************************************************************************/
class PpuMemRdPacket : public DbgPacket
{
public:
    PpuMemRdPacket(USHORT addr, USHORT numBytes);
    virtual ~PpuMemRdPacket() {};

    virtual UINT SizeInBytes() const;
    virtual UINT ReturnBytesExpected() const;

private:
    PpuMemRdPacket();
    PpuMemRdPacket& operator=(const PpuMemRdPacket&);
    PpuMemRdPacket(const PpuMemRdPacket&);
};

/***************************************************************************************************
** % Class:       PpuMemWrPacket
*  % Description: PPU memory write debug packet.
***************************************************************************************************/
class PpuMemWrPacket : public DbgPacket
{
public:
    PpuMemWrPacket(USHORT addr, USHORT numBytes, const BYTE* pData);
    virtual ~PpuMemWrPacket() {};

    virtual UINT SizeInBytes() const;
    virtual UINT ReturnBytesExpected() const;

private:
    PpuMemWrPacket();
    PpuMemWrPacket& operator=(const PpuMemRdPacket&);
    PpuMemWrPacket(const PpuMemRdPacket&);
};

/***************************************************************************************************
** % Class:       PpuDisablePacket
*  % Description: PPU disable debug packet.
***************************************************************************************************/
class PpuDisablePacket : public DbgPacket
{
public:
    PpuDisablePacket();
    virtual ~PpuDisablePacket() {};

    virtual UINT SizeInBytes() const { return 1; }
    virtual UINT ReturnBytesExpected() const { return 0; }

private:
    PpuDisablePacket& operator=(const PpuDisablePacket&);
    PpuDisablePacket(const PpuDisablePacket&);
};

/***************************************************************************************************
** % Class:       CartSetCfgPacket
*  % Description: Set cartridge configuration based on iNES header.
***************************************************************************************************/
class CartSetCfgPacket : public DbgPacket
{
public:
    CartSetCfgPacket(const BYTE* pINesHeader);
    virtual ~CartSetCfgPacket() {};

    virtual UINT SizeInBytes() const;
    virtual UINT ReturnBytesExpected() const { return 0; }

private:
    CartSetCfgPacket();
    CartSetCfgPacket& operator=(const CartSetCfgPacket&);
    CartSetCfgPacket(const CartSetCfgPacket&);
};

#endif // DBGPACKET_H
