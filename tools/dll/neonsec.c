/*
 * neonsec.dll - tiny helper for NeonScript: protects saved passwords and API tokens with
 * Windows DPAPI, so they are no longer plain text in profiles.ini.
 *
 *   $dll(neonsec.dll, Protect,   <text>)       ->  dpapi:<base64>
 *   $dll(neonsec.dll, Unprotect, dpapi:<b64>)  ->  <text>        (or "error:...")
 *   $dll(neonsec.dll, Version,   x)            ->  neonsec 1.0
 *
 * What DPAPI gives you: the data can only be decrypted by the same Windows user account on the same
 * PC.  Copy profiles.ini to another machine and the tokens are useless there (you re-enter them).
 * What it does not give you: protection from other programs running as YOU.
 *
 * Deliberately small and boring: only Win32 calls (kernel32, crypt32), no C runtime, no network,
 * no files, no registry, no threads, no state.  ANSI strings (mIRC's default DLL interface).
 * Licence: MIT (see LICENSE in the NeonScript folder).
 */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <wincrypt.h>

#define MAX_IN 256              /* longest secret we accept (bytes)                          */
#define PREFIX "dpapi:"
#define PREFIX_LEN 6

static DWORD g_max = 900;       /* size of mIRC's data buffer (bytes); LoadDll updates it   */
static const char ENTROPY[] = "NeonScript2026";   /* binds blobs to this app - not a secret */

typedef struct {
    DWORD mVersion;
    HWND  mHwnd;
    BOOL  mKeep;
    BOOL  mUnicode;
    DWORD mBeta;
    DWORD mBytes;
} LOADINFO;

BOOL WINAPI DllMain(HINSTANCE h, DWORD reason, LPVOID reserved)
{
    (void)h; (void)reason; (void)reserved;
    return TRUE;
}

void __stdcall LoadDll(LOADINFO *li)
{
    li->mKeep = FALSE;               /* unload after every call: nothing stays in memory */
    li->mUnicode = FALSE;
    if (li->mBytes >= 256) g_max = li->mBytes;
}

int __stdcall UnloadDll(int timeout)
{
    (void)timeout;
    return 1;
}

static int len(const char *s)
{
    int n = 0;
    while (s[n]) n++;
    return n;
}

static int fail(char *data, const char *msg)
{
    int i = 0;
    while (msg[i] && i < 120) { data[i] = msg[i]; i++; }
    data[i] = 0;
    return 3;
}

int __stdcall Version(HWND mWnd, HWND aWnd, char *data, char *parms, BOOL show, BOOL nopause)
{
    (void)mWnd; (void)aWnd; (void)parms; (void)show; (void)nopause;
    return fail(data, "neonsec 1.0");
}

int __stdcall Protect(HWND mWnd, HWND aWnd, char *data, char *parms, BOOL show, BOOL nopause)
{
    DATA_BLOB in, out, ent;
    DWORD n = 0;
    int i;
    (void)mWnd; (void)aWnd; (void)parms; (void)show; (void)nopause;

    in.cbData = (DWORD)len(data);
    in.pbData = (BYTE *)data;
    if (in.cbData == 0)      return fail(data, "error:nothing to protect");
    if (in.cbData > MAX_IN)  return fail(data, "error:too long");

    ent.pbData = (BYTE *)ENTROPY;
    ent.cbData = sizeof(ENTROPY) - 1;

    if (!CryptProtectData(&in, L"NeonScript", &ent, NULL, NULL, CRYPTPROTECT_UI_FORBIDDEN, &out))
        return fail(data, "error:protect failed");

    if (!CryptBinaryToStringA(out.pbData, out.cbData, CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF, NULL, &n)
        || n + PREFIX_LEN + 1 > g_max || n + PREFIX_LEN + 1 > 4000) {
        LocalFree(out.pbData);
        return fail(data, "error:result too long");
    }
    {
        /* write the prefix first, then the base64 text after it */
        char *dst = data + PREFIX_LEN;
        DWORD m = n;
        if (!CryptBinaryToStringA(out.pbData, out.cbData, CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF, dst, &m)) {
            LocalFree(out.pbData);
            return fail(data, "error:encode failed");
        }
        for (i = 0; i < PREFIX_LEN; i++) data[i] = PREFIX[i];
    }
    LocalFree(out.pbData);
    return 3;
}

int __stdcall Unprotect(HWND mWnd, HWND aWnd, char *data, char *parms, BOOL show, BOOL nopause)
{
    DATA_BLOB in, out, ent;
    DWORD n = 0;
    int i;
    char *b64;
    (void)mWnd; (void)aWnd; (void)parms; (void)show; (void)nopause;

    for (i = 0; i < PREFIX_LEN; i++)
        if (data[i] != PREFIX[i]) return fail(data, "error:not a protected value");
    b64 = data + PREFIX_LEN;

    if (!CryptStringToBinaryA(b64, 0, CRYPT_STRING_BASE64, NULL, &n, NULL, NULL) || n == 0)
        return fail(data, "error:bad encoding");
    in.pbData = (BYTE *)LocalAlloc(LMEM_FIXED, n);
    if (!in.pbData) return fail(data, "error:out of memory");
    in.cbData = n;
    if (!CryptStringToBinaryA(b64, 0, CRYPT_STRING_BASE64, in.pbData, &n, NULL, NULL)) {
        LocalFree(in.pbData);
        return fail(data, "error:bad encoding");
    }
    ent.pbData = (BYTE *)ENTROPY;
    ent.cbData = sizeof(ENTROPY) - 1;

    if (!CryptUnprotectData(&in, NULL, &ent, NULL, NULL, CRYPTPROTECT_UI_FORBIDDEN, &out)) {
        LocalFree(in.pbData);
        return fail(data, "error:cannot unlock (different Windows account or PC?)");
    }
    LocalFree(in.pbData);
    if (out.cbData == 0 || out.cbData > MAX_IN || out.cbData + 1 > g_max) {
        SecureZeroMemory(out.pbData, out.cbData);
        LocalFree(out.pbData);
        return fail(data, "error:unexpected size");
    }
    for (i = 0; i < (int)out.cbData; i++) data[i] = (char)out.pbData[i];
    data[out.cbData] = 0;
    SecureZeroMemory(out.pbData, out.cbData);
    LocalFree(out.pbData);
    return 3;
}
