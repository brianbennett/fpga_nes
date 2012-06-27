/***************************************************************************************************
** fpga_nes/sw/src/util.h
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
*  NesDbg utility header.
***************************************************************************************************/

#ifndef UTIL_H
#define UTIL_H

#include <windows.h>
#include <tchar.h>
#include <stdio.h>

#if _DEBUG

/***************************************************************************************************
** % Function:    Assert
*  % Description: Displays a message box with relevant assert data then issues a debug break.
***************************************************************************************************/
static inline VOID Assert(
    VOID* pExpr,  // expression string
    VOID* pFile,  // file string
    UINT line)    // line number
{
    static const UINT BufferLen = 256;
    char buffer[BufferLen];

    static char* pAssertString = "Assertion failed:\t(%s)\nFile:\t\t%s\nLine:\t\t%d\n";
    sprintf_s(buffer, BufferLen, pAssertString, pExpr, pFile, line);

    MessageBoxA(NULL, buffer, "ASSERTION FAILED", MB_OK | MB_ICONHAND | MB_TASKMODAL);
    DebugBreak();
}

#define assert(exp) (VOID)((exp) || (Assert(#exp, __FILE__, __LINE__), 0))

#else

#define assert(exp) (VOID)(exp)

#endif // DEBUG

#ifdef  _UNICODE

/***************************************************************************************************
** % Function:    CreateAsciiString
*  % Description: Creates an ascii string version of the specified TCHAR string.
*  % Returns:     CHAR array matching the specified input.
***************************************************************************************************/
static inline CHAR* CreateAsciiString(
    const TCHAR* pIn)
{
    assert(pIn);
    const UINT strLen = _tcslen(pIn);

    CHAR* pAscii = new CHAR[strLen + 1];

    size_t returnVal;
    wcstombs_s(&returnVal, pAscii, strLen + 1, pIn, strLen);

    return pAscii;
}

/***************************************************************************************************
** % Function:    DestroyAsciiString
*  % Description: Releases the ascii string created by CreateAsciiString().
*  % Returns:     N/A
***************************************************************************************************/
static inline VOID DestroyAsciiString(
    const CHAR* pIn)
{
    delete [] pIn;
}

/***************************************************************************************************
** % Function:    CreateTcharString
*  % Description: Creates a TCHAR string version of the specified ascii string.
*  % Returns:     TCHAR array matching the specified input.
***************************************************************************************************/
static inline TCHAR* CreateTcharString(
    const CHAR* pIn)
{
    assert(pIn);
    const UINT strLen = strlen(pIn);

    TCHAR* pTchar = new TCHAR[strLen + 1];

    size_t returnVal;
    mbstowcs_s(&returnVal, pTchar, strLen + 1, pIn, strLen);

    return pTchar;
}

/***************************************************************************************************
** % Function:    DestroyTcharString
*  % Description: Releases the TCHAR string created by CreateTcharString().
*  % Returns:     N/A
***************************************************************************************************/
static inline VOID DestroyTcharString(
    const TCHAR* pIn)
{
    delete [] pIn;
}

#else // _UNICODE

/***************************************************************************************************
** % Function:    CreateAsciiString
*  % Description: Creates an ascii string version of the specified TCHAR string.
*  % Returns:     CHAR array matching the specified input.
***************************************************************************************************/
static inline CHAR* CreateAsciiString(
    const TCHAR* pIn)
{
    // CHAR/TCHAR are equivalent for non-unicode builds.
    return pIn;
}

/***************************************************************************************************
** % Function:    DestroyAsciiString
*  % Description: Releases the ascii string created by CreateAsciiString().
*  % Returns:     N/A
***************************************************************************************************/
static inline VOID DestroyAsciiString(
    const CHAR* pIn)
{
}

/***************************************************************************************************
** % Function:    CreateTcharString
*  % Description: Creates a TCHAR string version of the specified ascii string.
*  % Returns:     TCHAR array matching the specified input.
***************************************************************************************************/
static inline TCHAR* CreateTcharString(
    const CHAR* pIn)
{
    // CHAR/TCHAR are equivalent for non-unicode builds.
    return pIn;
}

/***************************************************************************************************
** % Function:    DestroyTcharString
*  % Description: Releases the TCHAR string created by CreateTcharString().
*  % Returns:     N/A
***************************************************************************************************/
static inline VOID DestroyTcharString(
    const TCHAR* pIn)
{
}

#endif // _UNICODE

#endif // UTIL_H

