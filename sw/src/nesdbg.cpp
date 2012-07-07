/***************************************************************************************************
** fpga_nes/nesdbg/nesdbg.cpp
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
*  NesDbg class implementation.
***************************************************************************************************/

#include "dbgpacket.h"
#include "nesdbg.h"
#include "resource.h"
#include "scriptmgr.h"
#include "serialcomm.h"

/***************************************************************************************************
** % Method:      NesDbg::NesDbg()
*  % Description: NesDbg constructor.
***************************************************************************************************/
NesDbg::NesDbg(
    HINSTANCE hInstance,  // handle to application instance
    HWND      hWnd)       // handle to main application window
    :
    m_hInstance(hInstance),
    m_hWnd(hWnd),
    m_hFontCourierNew(NULL),
    m_pSerialComm(NULL),
    m_pScriptMgr(NULL)
{
}

/***************************************************************************************************
** % Method:      NesDbg::~NesDbg()
*  % Description: NesDbg destructor.
***************************************************************************************************/
NesDbg::~NesDbg()
{
    BOOL ret;

    if (m_hFontCourierNew)
    {
        ret = DeleteObject(m_hFontCourierNew);
    }

    if (m_pSerialComm)
    {
        delete m_pSerialComm;
    }

    if (m_pScriptMgr)
    {
        delete m_pScriptMgr;
    }
}

/***************************************************************************************************
** % Method:      NesDbg::Init()
*  % Description: NesDbg initialization method.  Must be called before any other method.
*  % Returns:     TRUE on success, FALSE otherwise.
***************************************************************************************************/
BOOL NesDbg::Init()
{
    BOOL ret = TRUE;

    // Initialize Courier New font object.
    if (ret)
    {
        m_hFontCourierNew = CreateFont(
            14,                  // nHeight
            0,                   // nWidth
            0,                   // nEscapement
            0,                   // nOrientation
            FW_DONTCARE,         // fnWeight
            FALSE,               // fdwItalic
            FALSE,               // fdwUnderline
            FALSE,               // fdwStrikeOut
            DEFAULT_CHARSET,     // fdwCharSet
            OUT_DEFAULT_PRECIS,  // fdwOutputPrecision
            CLIP_DEFAULT_PRECIS, // fdwClipPrecision
            DEFAULT_QUALITY,     // fdwQuality
            FIXED_PITCH,         // fdwPitchAndFamily
            _T("Courier New")    // lpszFace
        );

        if (m_hFontCourierNew == NULL)
        {
            ret = FALSE;
        }
    }

    // Initialize the serial communication manager object.
    if (ret)
    {
        m_pSerialComm = new SerialComm();
        if (m_pSerialComm && !m_pSerialComm->Init())
        {
            delete m_pSerialComm;
            m_pSerialComm = NULL;
        }
        ret = (m_pSerialComm) ? TRUE : FALSE;
    }

    // Initialize the script manager object.
    if (ret)
    {
        m_pScriptMgr = new ScriptMgr(this);
        if (m_pScriptMgr && !m_pScriptMgr->Init())
        {
            delete m_pScriptMgr;
            m_pScriptMgr = NULL;
        }
        ret = (m_pScriptMgr) ? TRUE : FALSE;
    }

    return ret;
}

/***************************************************************************************************
** % Method:      NesDbg::LaunchRawDbgDlg()
*  % Description: Launch the raw debugging interface.
***************************************************************************************************/
VOID NesDbg::LaunchRawDbgDlg()
{
    DialogBox(m_hInstance, _T("RawDebugDlg"), m_hWnd, RawDbgDlgProc);
}

/***************************************************************************************************
** % Method:      NesDbg::LaunchTestScripts()
*  % Description: Launch the test script interface.
***************************************************************************************************/
VOID NesDbg::LaunchTestScriptDlg()
{
    DialogBox(m_hInstance, _T("TestScriptDlg"), m_hWnd, ScriptMgr::TestScriptDlgProc);
}

/***************************************************************************************************
** % Method:      NesDbg::LoadRom()
*  % Description: Load a NES ROM using a file loading dialog.
***************************************************************************************************/
VOID NesDbg::LoadRom()
{
    TCHAR filePath[1024] = _T("");

    OPENFILENAME ofn    = {0};
    ofn.lStructSize     = sizeof(ofn);
	ofn.lpstrFile       = &filePath[0];
	ofn.nMaxFile        = sizeof(filePath);
	ofn.lpstrFilter     = _T("NES ROMs\0*.NES\0");
	ofn.nFilterIndex    = 0;
	ofn.lpstrInitialDir = _T(".\\roms");
	ofn.Flags           = OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST;

	BOOL success = GetOpenFileName(&ofn);

    HANDLE hPrgFile = INVALID_HANDLE_VALUE;

    if (success)
    {
        hPrgFile = CreateFile(&filePath[0],
                              GENERIC_READ,
                              0,
                              NULL,
                              OPEN_EXISTING,
                              FILE_ATTRIBUTE_NORMAL,
                              NULL);

        success = (hPrgFile != INVALID_HANDLE_VALUE);

        if (!success)
        {
            MessageBox(NULL, _T("Failed to open ROM file."), _T("NesDbg"), MB_OK);
        }
    }

    BYTE* pFileData = NULL;
    DWORD fileDataSize = 0;

    if (success)
    {
        static const UINT FileDataBufferSize = 0x100000;

        pFileData = new BYTE[FileDataBufferSize];

        success = ReadFile(hPrgFile, pFileData, FileDataBufferSize, &fileDataSize, NULL);

        if (!success)
        {
            MessageBox(NULL, _T("Failed to read data from ROM file."), _T("NesDbg"), MB_OK);
        }
    }

    UINT prgRomBanks = 0;
    UINT chrRomBanks = 0;

    if (success)
    {
        if ((pFileData[0] != 'N') || (pFileData[1] != 'E') || (pFileData[2] != 'S') ||
            (pFileData[3] != 0x1A))
        {
            MessageBox(NULL, _T("Invalid ROM header."), _T("NesDbg"), MB_OK);
            success = FALSE;
        }

        prgRomBanks = pFileData[4];
        chrRomBanks = pFileData[5];

        if ((prgRomBanks > 2) || (chrRomBanks > 1))
        {
            MessageBox(NULL, _T("Too many ROM banks."), _T("NesDbg"), MB_OK);
            success = FALSE;
        }

        // Check mirror support.
        if (pFileData[6] & 0x08)
        {
            MessageBox(NULL,
                       _T("Only horizontal and vertical mirroring are supported."),
                       _T("NesDbg"), MB_OK);
            success = FALSE;
        }

        if ((((pFileData[6] & 0xF0) >> 4)| (pFileData[7] & 0xF0)) != 0)
        {
            MessageBox(NULL, _T("Only mapper 0 is supported."), _T("NesDbg"), MB_OK);
            success = FALSE;
        }
    }

    if (success)
    {
        FLOAT pctDone = 0.0f;

        HWND hDlg = CreateDialog(m_hInstance,
                                 _T("RomLoadProgressDlg"),
                                 m_hWnd,
                                 RomLoadProgressDlgProc);

        PBRANGE pbRange;
        SendDlgItemMessage(hDlg,
                           IDC_ROMLOAD_PROGRESS,
                           PBM_GETRANGE,
                           0,
                           (LPARAM)&pbRange);

        // Issue a debug break.
        DbgHltPacket dbgHltPacket;
        g_pNesDbg->GetSerialComm()->SendData(dbgHltPacket.PacketData(),
                                             dbgHltPacket.SizeInBytes());

        PpuDisablePacket ppuDisablePacket;
        g_pNesDbg->GetSerialComm()->SendData(ppuDisablePacket.PacketData(),
                                             ppuDisablePacket.SizeInBytes());

        // Set iNES header info to configure mappers.
        CartSetCfgPacket cartSetCfgPacket(&pFileData[0]);

        g_pNesDbg->GetSerialComm()->SendData(cartSetCfgPacket.PacketData(),
                                             cartSetCfgPacket.SizeInBytes());

        const UINT prgRomDataSize    = prgRomBanks * 0x4000;
        const UINT chrRomDataSize    = chrRomBanks * 0x2000;
        const UINT totalBytes        = prgRomDataSize + chrRomDataSize;
        const UINT transferBlockSize = 0x400;

        UINT transferredBytes = 0;

        // Copy PRG ROM data.
        for (UINT i = 0; i < (prgRomDataSize / transferBlockSize); i++)
        {
            const UINT prgRomOffset = transferBlockSize * i;
            CpuMemWrPacket prgRomMemWrPacket(0x8000 + prgRomOffset,
                                             transferBlockSize,
                                             &pFileData[16 + prgRomOffset]);

            g_pNesDbg->GetSerialComm()->SendData(prgRomMemWrPacket.PacketData(),
                                                 prgRomMemWrPacket.SizeInBytes());

            transferredBytes += transferBlockSize;
            pctDone = (FLOAT)transferredBytes / totalBytes;

            const INT pos = (INT)(((pbRange.iHigh - pbRange.iLow) * pctDone) + pbRange.iLow);
            SendDlgItemMessage(hDlg, IDC_ROMLOAD_PROGRESS, PBM_SETPOS, (WPARAM)pos, 0);
        }

        // Copy CHR ROM data.
        for (UINT i = 0; i < (chrRomDataSize / transferBlockSize); i++)
        {
            const UINT chrRomOffset = transferBlockSize * i;
            PpuMemWrPacket ppuMemWrPacket(chrRomOffset,
                                          transferBlockSize,
                                          &pFileData[16 + prgRomDataSize + chrRomOffset]);

            g_pNesDbg->GetSerialComm()->SendData(ppuMemWrPacket.PacketData(),
                                                 ppuMemWrPacket.SizeInBytes());

            transferredBytes += transferBlockSize;
            pctDone = (FLOAT)transferredBytes / totalBytes;

            const INT pos = (INT)(((pbRange.iHigh - pbRange.iLow) * pctDone) + pbRange.iLow);
            SendDlgItemMessage(hDlg, IDC_ROMLOAD_PROGRESS, PBM_SETPOS, (WPARAM)pos, 0);
        }

        // Update PC to point at the reset interrupt vector location.
        BYTE pclVal = pFileData[16 + prgRomDataSize - 4];
        BYTE pchVal = pFileData[16 + prgRomDataSize - 3];

        CpuRegWrPacket pclRegWrPacket(CpuRegPcl, pclVal);
        g_pNesDbg->GetSerialComm()->SendData(pclRegWrPacket.PacketData(),
                                             pclRegWrPacket.SizeInBytes());
        CpuRegWrPacket pchRegWrPacket(CpuRegPch, pchVal);
        g_pNesDbg->GetSerialComm()->SendData(pchRegWrPacket.PacketData(),
                                             pchRegWrPacket.SizeInBytes());

        // Issue a debug run command.
        DbgRunPacket dbgRunPacket;
        g_pNesDbg->GetSerialComm()->SendData(dbgRunPacket.PacketData(),
                                             dbgRunPacket.SizeInBytes());

        DestroyWindow(hDlg);
    }

    if (pFileData != NULL)
    {
        delete [] pFileData;
    }

    if (hPrgFile != INVALID_HANDLE_VALUE)
    {
        CloseHandle(hPrgFile);
    }
}

/***************************************************************************************************
** % Method:      NesDbg::GetMessageBoxTitle()
*  % Description: Returns a string to be used as the title of all message boxes for the app.
***************************************************************************************************/
const TCHAR* NesDbg::GetMessageBoxTitle()
{
    static const TCHAR* pMsgBoxTitle = _T("NesDbg");
    return pMsgBoxTitle;
}

/***************************************************************************************************
** % Method:      NesDbg::RawDbgDlgProc()
*  % Description: Raw Debug dialog proc callback implementation.
*  % Returns:     TRUE if message was handled, FALSE otherwise.
***************************************************************************************************/
BOOL CALLBACK NesDbg::RawDbgDlgProc(
    HWND   hWndDlg,  // handle to the dialog box
    UINT   msg,      // message
    WPARAM wParam,   // message-specific information
    LPARAM lParam)   // additional message-specific information
{
    BOOL   ret            = TRUE;

    TCHAR* pInput         = NULL;
    TCHAR* pOutput        = NULL;
    TCHAR* pOutputPtr     = NULL;
    BYTE*  pReceivedData  = NULL;

    DWORD  cmdLength      = 0;
    DWORD  nibbleIdx      = 0;
    DWORD  bytesWritten   = 0;
    UINT   bytesToReceive = 0;

    DbgPacket* pDbgPacket = NULL;

    switch (msg)
    {
        case WM_INITDIALOG:
            SendDlgItemMessage(
                hWndDlg,
                IDC_RAWDBG_OUT,
                WM_SETFONT,
                (WPARAM)g_pNesDbg->m_hFontCourierNew,
                FALSE);
            break;
        case WM_COMMAND:
            switch (LOWORD(wParam))
            {
                case IDC_RAWDBG_SEND:
                    cmdLength = SendDlgItemMessage(hWndDlg, IDC_RAWDBG_IN, WM_GETTEXTLENGTH, 0, 0);

                    pInput = new TCHAR[cmdLength + 1];

                    SendDlgItemMessage(hWndDlg,
                                       IDC_RAWDBG_IN,
                                       WM_GETTEXT,
                                       cmdLength + 1,
                                       (LPARAM)pInput);

                    pDbgPacket = DbgPacket::CreateObjFromString(pInput);

                    if (pDbgPacket)
                    {
                        g_pNesDbg->m_pSerialComm->SendData(pDbgPacket->PacketData(),
                                                           pDbgPacket->SizeInBytes());

                        bytesToReceive = pDbgPacket->ReturnBytesExpected();

                        pReceivedData = new BYTE[bytesToReceive];

                        g_pNesDbg->m_pSerialComm->ReceiveData(pReceivedData, bytesToReceive);

                        pOutput = new TCHAR[bytesToReceive * 3 + 1];

                        pOutputPtr = pOutput;
                        for (UINT i = 0; i < bytesToReceive; i++)
                        {
                            BYTE byte     = pReceivedData[i];
                            BYTE hiNibble = byte >> 4;
                            BYTE loNibble = byte & 0xF;

                            *pOutputPtr++ = (hiNibble > 9)
                                          ? (_T('A') + (hiNibble - 0xA))
                                          : _T('0') + hiNibble;
                            *pOutputPtr++ = (loNibble > 9)
                                          ? (_T('A') + (loNibble - 0xA))
                                          : _T('0') + loNibble;
                            *pOutputPtr++ = _T(' ');
                        }

                        *pOutputPtr++ = 0;

                        SendDlgItemMessage(hWndDlg, IDC_RAWDBG_OUT, WM_SETTEXT, 0, (LPARAM)pOutput);

                        delete [] pReceivedData;
                        delete [] pOutput;

                        pDbgPacket->Destroy();

                        // Clear input text.
                        SendDlgItemMessage(hWndDlg, IDC_RAWDBG_IN, WM_SETTEXT, 0, (LPARAM)_T(""));
                    }
                    else
                    {
                        MessageBox(NULL,
                                   _T("Invalid data."),
                                   g_pNesDbg->GetMessageBoxTitle(),
                                   MB_OK);
                    }

                    delete [] pInput;
                    break;
                case IDC_RAWDBG_CLEAR:
                    // Clear output text.
                    SendDlgItemMessage(hWndDlg, IDC_RAWDBG_OUT, WM_SETTEXT, 0, (LPARAM)_T(""));
                    break;
                case IDC_RAWDBG_DONE:
                case IDCANCEL:
                    EndDialog(hWndDlg, wParam);
                    break;
                default:
                    ret = FALSE;
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
** % Method:      NesDbg::RomLoadProgressDlgProc()
*  % Description: Modeless dialog to show progress of ROM loads.
*  % Returns:     TRUE if message was handled, FALSE otherwise.
***************************************************************************************************/
BOOL CALLBACK NesDbg::RomLoadProgressDlgProc(
    HWND   hWndDlg,  // handle to the dialog box
    UINT   msg,      // message
    WPARAM wParam,   // message-specific information
    LPARAM lParam)   // additional message-specific information
{
    BOOL ret = TRUE;

    switch (msg)
    {
        case WM_INITDIALOG:
            break;
        default:
            ret = FALSE;
            break;
    }

    return ret;
}
