/***************************************************************************************************
** % File:        serialcomm.h
*  % Description: SerialComm class header.
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

