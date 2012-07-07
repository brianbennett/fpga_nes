/***************************************************************************************************
** fpga_nes/sw/src/serialcomm.cpp
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
*  SerialComm class implementation.
***************************************************************************************************/

#include <windows.h>
#include <tchar.h>

#include "dbgpacket.h"
#include "nesdbg.h"
#include "serialcomm.h"

/***************************************************************************************************
** % Method:      SerialComm::SerialComm()
*  % Description: SerialComm constructor.
***************************************************************************************************/
SerialComm::SerialComm()
{
}

/***************************************************************************************************
** % Method:      SerialComm::~SerialComm()
*  % Description: SerialComm destructor.
***************************************************************************************************/
SerialComm::~SerialComm()
{
    if (m_hSerialComm)
    {
        CloseHandle(m_hSerialComm);
    }
}

/***************************************************************************************************
** % Method:      SerialComm::Init()
*  % Description: SerialComm initialization method.  Must be called before any other method.
*  % Returns:     TRUE on success, FALSE otherwise.
*
*  % TODO:        Allow user configuration of serial connection (currently hardcoded to COM4, etc.)
***************************************************************************************************/
BOOL SerialComm::Init()
{
    BOOL ret = TRUE;

    if (ret)
    {
        m_hSerialComm = CreateFile(_T("COM5"),
                                   GENERIC_READ | GENERIC_WRITE,
                                   0,
                                   0,
                                   OPEN_EXISTING,
                                   FILE_ATTRIBUTE_NORMAL,
                                   0);

        if (m_hSerialComm == INVALID_HANDLE_VALUE)
        {
            ret = FALSE;
            if (GetLastError() == ERROR_FILE_NOT_FOUND)
            {
                MessageBox(NULL, _T("\"COM5\" file not found."), _T("NesDbg"), MB_OK);
            }
            else
            {
                MessageBox(NULL, _T("Unknown error initializing COM5"), _T("NesDbg"), MB_OK);
            }
        }
    }

    DCB serialConfig = {0};
    if (ret)
    {
        serialConfig.DCBlength = sizeof(DCB);

        if (!GetCommState(m_hSerialComm, &serialConfig))
        {
            ret = FALSE;
            MessageBox(NULL, _T("Error getting comm state for COM5."), _T("NesDbg"), MB_OK);
        }
    }

    if (ret)
    {
        serialConfig.BaudRate = CBR_38400;
        serialConfig.ByteSize = 8;
        serialConfig.StopBits = ONESTOPBIT;
        serialConfig.Parity   = ODDPARITY;

        if (!SetCommState(m_hSerialComm, &serialConfig))
        {
            ret = FALSE;
            MessageBox(NULL, _T("Error setting comm state for COM5."), _T("NesDbg"), MB_OK);
        }
    }

    if (ret)
    {
        COMMTIMEOUTS timeouts = {0};

        timeouts.ReadIntervalTimeout         = 50;
        timeouts.ReadTotalTimeoutMultiplier  = 10;
        timeouts.ReadTotalTimeoutConstant    = 5000;
        timeouts.WriteTotalTimeoutMultiplier = 10;
        timeouts.WriteTotalTimeoutConstant   = 50;

        if (!SetCommTimeouts(m_hSerialComm, &timeouts))
        {
            ret = FALSE;
            MessageBox(NULL, _T("Error setting timeout state for COM5."), _T("NesDbg"), MB_OK);
        }
    }

    if (ret)
    {
        // Add short sleep here.  The first serial read/write fails sometimes if it occurs to soon
        // after init.
        Sleep(200);

        // Send a debug echo packet to the NES to verify the connection.
        const char* pInitString = "NES";
        const UINT initStringSize = strlen(pInitString) + 1;

        EchoPacket initEchoPkt(reinterpret_cast<const BYTE*>(pInitString), initStringSize);

        SendData(initEchoPkt.PacketData(), initEchoPkt.SizeInBytes());

        UINT bytesToReceive = initEchoPkt.ReturnBytesExpected();

        char* pOutString = new char[bytesToReceive];

        ReceiveData(reinterpret_cast<BYTE*>(pOutString), bytesToReceive);

        if (strcmp(pInitString, pOutString))
        {
            ret = FALSE;
            MessageBox(NULL, _T("NES FPGA not connected."), _T("NesDbg"), MB_OK);
        }

        delete [] pOutString;
    }

    return ret;
}

/***************************************************************************************************
** % Method:      SerialComm::SendData()
*  % Description: Transmits specified data through the serial port.
*  % Returns:     TRUE on success, FALSE otherwise.
***************************************************************************************************/
BOOL SerialComm::SendData(
    const BYTE* pData,     // data to transmit
    UINT        numBytes)  // number of bytes to transmit
{
    BOOL  ret          = TRUE;
    DWORD bytesWritten = 0;

    ret = WriteFile(m_hSerialComm, pData, numBytes, &bytesWritten, NULL);

    assert(bytesWritten == numBytes);
    if (bytesWritten != numBytes)
    {
        ret = FALSE;
    }

    return ret;
}

/***************************************************************************************************
** % Method:      SerialComm::ReceiveData()
*  % Description: Receives specified number of bytes through the serial port, and stores them at
*                 the location specified by pData.
*  % Returns:     TRUE on success, FALSE otherwise.
***************************************************************************************************/
BOOL SerialComm::ReceiveData(
    BYTE* pData,     // where to store received data
    UINT  numBytes)  // number of bytes to receive
{
    BOOL  ret       = TRUE;
    DWORD bytesRead = 0;

    ret = ReadFile(m_hSerialComm, pData, numBytes, &bytesRead, NULL);

    assert(bytesRead == numBytes);
    if (bytesRead != numBytes)
    {
        ret = FALSE;
    }

    return ret;
}
