/***************************************************************************************************
** fpga_nes/sw/src/serialcomm.h
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
*  SerialComm class header.
***************************************************************************************************/

#ifndef SERIALCOMM_H
#define SERIALCOMM_H

/***************************************************************************************************
** % Class:       SerialComm
*  % Description: Manages communication with NES FPGA through serial port.
***************************************************************************************************/
class SerialComm
{
public:
    SerialComm();
    ~SerialComm();

    BOOL Init();

    BOOL SendData(const BYTE* pData, UINT numBytes);
    BOOL ReceiveData(BYTE* pData, UINT numBytes);

private:
    SerialComm& operator=(const SerialComm&);
    SerialComm(const SerialComm&);

    HANDLE m_hSerialComm;  // win32 handle to debug serial port
};

#endif // SERIALCOMM_H

