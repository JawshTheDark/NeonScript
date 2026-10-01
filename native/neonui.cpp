/*
 * neonui.dll - the optional native helper for NeonScript 2026.  32-bit (mIRC is a 32-bit program).
 *
 *   $dll(neonui.dll, Cmd, <verb><TAB><arg><TAB><arg>...)      returns the result text
 *
 * What it does (and nothing else):
 *   nlscan / nlcfg / nlunhook   rank icons and coloured initials ("avatars") in the nick list of every channel window
 *   badge / progress            unread count on mIRC's taskbar button, progress bar on the taskbar button
 *   ver                         version text
 * It never opens a network connection, never reads or writes files, and only touches mIRC's own windows.
 * NeonScript checks this file's SHA-256 against data\neonui.sha256 before it ever loads it.
 *
 * How the nick list is drawn: mIRC's nick list is an owner-drawn list box whose items are painted by mIRC's channel
 * window (WM_DRAWITEM).  The DLL subclasses that channel window, lets mIRC paint the item into an off-screen bitmap
 * that is 'need' pixels narrower, then copies the bitmap shifted to the right and paints the icons in the space it
 * freed.  mIRC's own colours, fonts, selection and away dimming are untouched.
 *
 * Licence: MIT (see LICENSE in the NeonScript folder).
 */
#define NOMINMAX
#include <windows.h>
#include <algorithm>
using std::min;
using std::max;
#include <objidl.h>
#include <gdiplus.h>
#include <commctrl.h>
#include <shobjidl.h>
#include <cmath>
#include <cstdlib>
#include <cwchar>
#include <map>
#include <string>
#include <vector>

#define NEONUI_VERSION L"neonui 1.0"

typedef struct {
    DWORD mVersion;
    HWND  mHwnd;
    BOOL  mKeep;
    BOOL  mUnicode;
    DWORD mBeta;
    DWORD mBytes;
} LOADINFO;

static HWND      g_mirc = nullptr;
static BOOL      g_unicode = FALSE;
static DWORD     g_bytes = 8192;
static ULONG_PTR g_gdip = 0;
static bool      g_gdipOk = false;
static HMODULE   g_self = nullptr;

BOOL WINAPI DllMain(HINSTANCE h, DWORD reason, LPVOID)
{
    if (reason == DLL_PROCESS_ATTACH) {
        g_self = h;
        DisableThreadLibraryCalls(h);
    }
    return TRUE;
}

/* ===================================================================================== helpers */
static std::vector<std::wstring> Split(const std::wstring &s, wchar_t sep)
{
    std::vector<std::wstring> out;
    size_t a = 0;
    for (;;) {
        size_t b = s.find(sep, a);
        if (b == std::wstring::npos) { out.push_back(s.substr(a)); break; }
        out.push_back(s.substr(a, b - a));
        a = b + 1;
    }
    return out;
}

/* "key=value" lookup among the arguments after the verb */
static std::wstring Opt(const std::vector<std::wstring> &a, const wchar_t *key, const wchar_t *def = L"")
{
    size_t n = wcslen(key);
    for (size_t i = 1; i < a.size(); i++)
        if (a[i].size() > n && a[i][n] == L'=' && a[i].compare(0, n, key) == 0) return a[i].substr(n + 1);
    return def;
}

static COLORREF HexColour(const std::wstring &s, COLORREF def)
{
    if (s.size() != 6) return def;
    wchar_t *end = nullptr;
    unsigned long v = wcstoul(s.c_str(), &end, 16);
    if (!end || *end) return def;
    return RGB((v >> 16) & 255, (v >> 8) & 255, v & 255);
}

/* ===================================================================================== nick list */
struct Config {
    bool rank = true;
    bool avatar = true;
    COLORREF rankCol[5] = { RGB(0xF2, 0xB8, 0x2E), RGB(0xE8, 0x6A, 0x4F), RGB(0x3F, 0xC1, 0x6B), RGB(0x2E, 0xC4, 0xB6), RGB(0x5B, 0x9B, 0xF0) };
};
static Config g_cfg;
static std::map<HWND, bool> g_hooks;
static const UINT_PTR HOOK_ID = 0x4E55;     /* "NU" */

static int RankIndex(wchar_t c)             /* q a o h v  ->  0..4 */
{
    switch (c) {
    case L'~': return 0;
    case L'&': return 1;
    case L'@': return 2;
    case L'%': return 3;
    case L'+': return 4;
    }
    return -1;
}

static void RankShape(Gdiplus::Graphics &g, int r, float x, float y, float s, COLORREF c)
{
    using namespace Gdiplus;
    Color col(255, GetRValue(c), GetGValue(c), GetBValue(c));
    SolidBrush br(col);
    float pw = max(1.4f, s * 0.17f);
    Pen pen(col, pw);
    switch (r) {
    case 0: {                                        /* owner: star */
        PointF p[10];
        float cx = x + s / 2, cy = y + s / 2 + s * 0.04f, ro = s / 2, ri = s * 0.22f;
        for (int i = 0; i < 10; i++) {
            float ang = -3.14159265f / 2 + i * 3.14159265f / 5, rad = (i % 2 == 0) ? ro : ri;
            p[i] = PointF(cx + cosf(ang) * rad, cy + sinf(ang) * rad);
        }
        g.FillPolygon(&br, p, 10);
        break;
    }
    case 1: {                                        /* admin: diamond */
        PointF p[4] = { PointF(x + s / 2, y), PointF(x + s, y + s / 2), PointF(x + s / 2, y + s), PointF(x, y + s / 2) };
        g.FillPolygon(&br, p, 4);
        break;
    }
    case 2:                                          /* op: solid disc */
        g.FillEllipse(&br, x, y, s, s);
        break;
    case 3:                                          /* halfop: ring, left half filled */
        g.DrawEllipse(&pen, x + pw / 2, y + pw / 2, s - pw, s - pw);
        g.FillPie(&br, x, y, s, s, 90.0f, 180.0f);
        break;
    case 4:                                          /* voice: ring */
        g.DrawEllipse(&pen, x + pw / 2, y + pw / 2, s - pw, s - pw);
        break;
    }
}

static COLORREF HslToRgb(float h, float s, float l)
{
    float c = (1 - fabsf(2 * l - 1)) * s, hp = h / 60.0f, x = c * (1 - fabsf(fmodf(hp, 2.0f) - 1)), r = 0, g = 0, b = 0;
    if (hp < 1) { r = c; g = x; }
    else if (hp < 2) { r = x; g = c; }
    else if (hp < 3) { g = c; b = x; }
    else if (hp < 4) { g = x; b = c; }
    else if (hp < 5) { r = x; b = c; }
    else { r = c; b = x; }
    float m = l - c / 2;
    return RGB((int)((r + m) * 255 + 0.5f), (int)((g + m) * 255 + 0.5f), (int)((b + m) * 255 + 0.5f));
}

static void Avatar(Gdiplus::Graphics &g, const wchar_t *nick, float x, float y, float d)
{
    using namespace Gdiplus;
    unsigned h = 2166136261u;
    for (const wchar_t *p = nick; *p; p++) { h ^= (unsigned)towlower(*p); h *= 16777619u; }
    COLORREF c = HslToRgb((float)(h % 360), 0.50f, 0.42f);
    SolidBrush br(Color(255, GetRValue(c), GetGValue(c), GetBValue(c)));
    g.FillEllipse(&br, x, y, d, d);
    wchar_t ch[2] = { L'?', 0 };
    for (const wchar_t *p = nick; *p; p++)
        if (iswalnum(*p)) { ch[0] = (wchar_t)towupper(*p); break; }
    FontFamily ff(L"Segoe UI");
    Font font(&ff, d * 0.56f, FontStyleBold, UnitPixel);
    StringFormat sf;
    sf.SetAlignment(StringAlignmentCenter);
    sf.SetLineAlignment(StringAlignmentCenter);
    SolidBrush white(Color(255, 255, 255, 255));
    RectF rc(x, y - 0.5f, d, d);
    g.DrawString(ch, 1, &font, rc, &sf, &white);
}

/* paint one nick list row: mIRC draws it narrower into memory, we copy it right and paint the icons on the left */
static bool DrawNick(HWND chan, WPARAM wp, DRAWITEMSTRUCT *d)
{
    if (!g_gdipOk || (!g_cfg.rank && !g_cfg.avatar)) return false;
    if (d->CtlType != ODT_LISTBOX || (int)d->itemID < 0) return false;
    RECT rc = d->rcItem;
    int W = rc.right - rc.left, H = rc.bottom - rc.top;
    if (H < 11 || W < 60) return false;
    float s = (float)(H - 4);                           /* icon size follows the row height */
    bool wantRank = g_cfg.rank, wantAv = g_cfg.avatar;
    /* a narrow nick list keeps room for the names: drop the avatars first, then the rank icons */
    if (wantRank && wantAv && W < (int)(2 * (s + 3)) + 60) wantAv = false;
    if (wantRank && !wantAv && W < (int)(s + 3) + 52) wantRank = false;
    if (!wantRank && wantAv && W < (int)(s + 3) + 52) wantAv = false;
    if (!wantRank && !wantAv) return false;
    int rankW = wantRank ? (int)(s + 3) : 0;
    int avW = wantAv ? (int)(s + 3) : 0;
    int need = rankW + avW + 1;

    wchar_t txt[96];
    LRESULT n = SendMessageW(d->hwndItem, LB_GETTEXT, d->itemID, (LPARAM)txt);
    if (n <= 0 || n >= 96) return false;
    txt[n] = 0;
    int rank = -1;
    const wchar_t *nick = txt;
    while (*nick && RankIndex(*nick) >= 0) {
        int r = RankIndex(*nick);
        if (rank < 0 || r < rank) rank = r;
        nick++;
    }

    HDC mem = CreateCompatibleDC(d->hDC);
    if (!mem) return false;
    HBITMAP bmp = CreateCompatibleBitmap(d->hDC, W - need, H);
    if (!bmp) { DeleteDC(mem); return false; }
    HGDIOBJ oldBmp = SelectObject(mem, bmp);
    HFONT font = (HFONT)SendMessageW(d->hwndItem, WM_GETFONT, 0, 0);
    HGDIOBJ oldFont = font ? SelectObject(mem, font) : nullptr;

    DRAWITEMSTRUCT d2 = *d;
    d2.hDC = mem;
    d2.rcItem.left = 0; d2.rcItem.top = 0; d2.rcItem.right = W - need; d2.rcItem.bottom = H;
    LRESULT res = DefSubclassProc(chan, WM_DRAWITEM, wp, (LPARAM)&d2);

    COLORREF bg = GetPixel(mem, W - need - 1, H / 2);
    if (bg == CLR_INVALID) bg = GetSysColor(COLOR_WINDOW);
    HBRUSH brush = CreateSolidBrush(bg);
    RECT left = { rc.left, rc.top, rc.left + need, rc.bottom };
    FillRect(d->hDC, &left, brush);
    DeleteObject(brush);
    BitBlt(d->hDC, rc.left + need, rc.top, W - need, H, mem, 0, 0, SRCCOPY);

    if (oldFont) SelectObject(mem, oldFont);
    SelectObject(mem, oldBmp);
    DeleteObject(bmp);
    DeleteDC(mem);

    {
        Gdiplus::Graphics g(d->hDC);
        g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
        g.SetTextRenderingHint(Gdiplus::TextRenderingHintAntiAliasGridFit);
        float x = (float)rc.left + 2, y = (float)rc.top + (H - s) / 2;
        if (wantRank) {
            if (rank >= 0) RankShape(g, rank, x + s * 0.08f, y + s * 0.08f, s * 0.84f, g_cfg.rankCol[rank]);
            x += rankW;
        }
        if (wantAv) Avatar(g, nick, x, y, s);
    }
    (void)res;
    return true;
}

static bool DrawNickSafe(HWND chan, WPARAM wp, DRAWITEMSTRUCT *d)
{
    __try {
        return DrawNick(chan, wp, d);
    } __except (EXCEPTION_EXECUTE_HANDLER) {
        g_cfg.rank = false;                             /* never crash mIRC twice */
        g_cfg.avatar = false;
        return false;
    }
}

static LRESULT CALLBACK ChanProc(HWND h, UINT m, WPARAM w, LPARAM l, UINT_PTR id, DWORD_PTR)
{
    if (m == WM_DRAWITEM && l) {
        DRAWITEMSTRUCT *d = (DRAWITEMSTRUCT *)l;
        if (d->CtlType == ODT_LISTBOX && DrawNickSafe(h, w, d)) return TRUE;
    } else if (m == WM_NCDESTROY) {
        RemoveWindowSubclass(h, ChanProc, id);
        g_hooks.erase(h);
    }
    return DefSubclassProc(h, m, w, l);
}

static HWND NickList(HWND chan)
{
    return FindWindowExW(chan, nullptr, L"ListBox", nullptr);
}

static void Repaint()
{
    for (auto &kv : g_hooks) {
        HWND list = NickList(kv.first);
        if (list) InvalidateRect(list, nullptr, TRUE);
    }
}

static BOOL CALLBACK ScanCb(HWND h, LPARAM)
{
    wchar_t cls[64];
    if (GetClassNameW(h, cls, 64) && wcscmp(cls, L"mIRC_Channel") == 0 && !g_hooks.count(h)) {
        if (SetWindowSubclass(h, ChanProc, HOOK_ID, 0)) g_hooks[h] = true;
    }
    return TRUE;
}

static int NickScan()
{
    for (auto it = g_hooks.begin(); it != g_hooks.end();) {
        if (!IsWindow(it->first)) it = g_hooks.erase(it);
        else ++it;
    }
    if (g_mirc && (g_cfg.rank || g_cfg.avatar)) EnumChildWindows(g_mirc, ScanCb, 0);
    return (int)g_hooks.size();
}

static void UnhookAll()
{
    for (auto &kv : g_hooks) {
        if (IsWindow(kv.first)) {
            RemoveWindowSubclass(kv.first, ChanProc, HOOK_ID);
            HWND list = NickList(kv.first);
            if (list) InvalidateRect(list, nullptr, TRUE);
        }
    }
    g_hooks.clear();
}

/* ===================================================================================== taskbar */
static ITaskbarList3 *g_tb = nullptr;
static HRESULT g_tbErr = S_OK;
static HICON g_badge = nullptr;

static bool TaskbarReady()
{
    if (g_tb) return true;
    if (!g_mirc) return false;
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);     /* S_FALSE / RPC_E_CHANGED_MODE are fine here */
    HRESULT hr = CoCreateInstance(CLSID_TaskbarList, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&g_tb));
    if (FAILED(hr)) { g_tb = nullptr; g_tbErr = hr; return false; }
    hr = g_tb->HrInit();
    if (FAILED(hr)) { g_tb->Release(); g_tb = nullptr; g_tbErr = hr; return false; }
    return true;
}

static std::wstring TaskbarError()
{
    wchar_t buf[48];
    swprintf(buf, 48, L"error:taskbar 0x%08X", (unsigned)g_tbErr);
    return buf;
}

static HICON MakeBadge(int n)
{
    using namespace Gdiplus;
    Bitmap bmp(16, 16, PixelFormat32bppARGB);
    {
        Graphics g(&bmp);
        g.SetSmoothingMode(SmoothingModeAntiAlias);
        g.SetTextRenderingHint(TextRenderingHintAntiAliasGridFit);
        g.Clear(Color(0, 0, 0, 0));
        SolidBrush red(Color(255, 0xE5, 0x48, 0x4D));
        Pen ring(Color(255, 255, 255, 255), 1.0f);
        g.FillEllipse(&red, 0.5f, 0.5f, 15.0f, 15.0f);
        g.DrawEllipse(&ring, 0.5f, 0.5f, 15.0f, 15.0f);
        wchar_t t[4] = { 0 };
        if (n > 9) { t[0] = L'9'; t[1] = L'+'; }
        else swprintf(t, 4, L"%d", n);
        FontFamily ff(L"Segoe UI");
        Font font(&ff, n > 9 ? 8.0f : 10.0f, FontStyleBold, UnitPixel);
        StringFormat sf;
        sf.SetAlignment(StringAlignmentCenter);
        sf.SetLineAlignment(StringAlignmentCenter);
        SolidBrush white(Color(255, 255, 255, 255));
        RectF rc(0, 0.5f, 16, 16);
        g.DrawString(t, -1, &font, rc, &sf, &white);
    }
    HICON ic = nullptr;
    bmp.GetHICON(&ic);
    return ic;
}

static std::wstring Badge(int n, const std::wstring &desc)
{
    if (!g_gdipOk) return L"error:gdiplus";
    if (!TaskbarReady()) return TaskbarError();
    if (n <= 0) {
        g_tb->SetOverlayIcon(g_mirc, nullptr, L"");
        if (g_badge) { DestroyIcon(g_badge); g_badge = nullptr; }
        return L"ok";
    }
    HICON ic = MakeBadge(n);
    if (!ic) return L"error:icon";
    g_tb->SetOverlayIcon(g_mirc, ic, desc.c_str());
    if (g_badge) DestroyIcon(g_badge);
    g_badge = ic;
    return L"ok";
}

static std::wstring Progress(const std::wstring &state, int pct)
{
    if (!TaskbarReady()) return TaskbarError();
    TBPFLAG f = TBPF_NOPROGRESS;
    if (state == L"indeterminate") f = TBPF_INDETERMINATE;
    else if (state == L"normal") f = TBPF_NORMAL;
    else if (state == L"error") f = TBPF_ERROR;
    else if (state == L"paused") f = TBPF_PAUSED;
    g_tb->SetProgressState(g_mirc, f);
    if (f == TBPF_NORMAL || f == TBPF_ERROR || f == TBPF_PAUSED) g_tb->SetProgressValue(g_mirc, (ULONGLONG)max(0, min(100, pct)), 100);
    return L"ok";
}

/* ===================================================================================== commands */
static std::wstring Run(const std::wstring &in)
{
    std::vector<std::wstring> a = Split(in, L'\t');
    const std::wstring &v = a[0];
    if (v == L"ver") return NEONUI_VERSION;
    if (v == L"nlcfg") {
        g_cfg.rank = Opt(a, L"rank", L"1") != L"0";
        g_cfg.avatar = Opt(a, L"avatar", L"1") != L"0";
        static const wchar_t *keys[5] = { L"q", L"a", L"o", L"h", L"v" };
        for (int i = 0; i < 5; i++) g_cfg.rankCol[i] = HexColour(Opt(a, keys[i]), g_cfg.rankCol[i]);
        if (!g_cfg.rank && !g_cfg.avatar) UnhookAll();
        else { NickScan(); Repaint(); }
        return L"ok";
    }
    if (v == L"nlscan") return std::to_wstring(NickScan());
    if (v == L"nlunhook") { UnhookAll(); return L"ok"; }
    if (v == L"badge") return Badge(a.size() > 1 ? _wtoi(a[1].c_str()) : 0, a.size() > 2 ? a[2] : L"");
    if (v == L"progress") return Progress(a.size() > 1 ? a[1] : L"", a.size() > 2 ? _wtoi(a[2].c_str()) : 0);
    return L"error:unknown command";
}

static void Respond(wchar_t *data, size_t cap)
{
    std::wstring out;
    try {
        out = Run(data);
    } catch (...) {
        out = L"error:exception";
    }
    wcsncpy_s(data, cap, out.c_str(), _TRUNCATE);
}

static void RespondSafe(wchar_t *data, size_t cap)
{
    __try {
        Respond(data, cap);
    } __except (EXCEPTION_EXECUTE_HANDLER) {
        wcsncpy_s(data, cap, L"error:crash", _TRUNCATE);
    }
}

static void Shutdown()
{
    UnhookAll();
    if (g_tb) {
        g_tb->SetOverlayIcon(g_mirc, nullptr, L"");
        g_tb->SetProgressState(g_mirc, TBPF_NOPROGRESS);
        g_tb->Release();
        g_tb = nullptr;
    }
    if (g_badge) { DestroyIcon(g_badge); g_badge = nullptr; }
    if (g_gdipOk) { Gdiplus::GdiplusShutdown(g_gdip); g_gdipOk = false; }
}

extern "C" void __stdcall LoadDll(LOADINFO *li)
{
    li->mKeep = TRUE;
    li->mUnicode = TRUE;
    g_mirc = li->mHwnd;
    g_unicode = TRUE;
    if (li->mBytes >= 1024) g_bytes = li->mBytes;
    if (!g_gdipOk) {
        Gdiplus::GdiplusStartupInput in;
        if (Gdiplus::GdiplusStartup(&g_gdip, &in, nullptr) == Gdiplus::Ok) g_gdipOk = true;
    }
}

extern "C" int __stdcall UnloadDll(int timeout)
{
    if (timeout == 1) return 0;                          /* idle for ten minutes: stay loaded, we hook windows */
    Shutdown();
    return 1;
}

extern "C" int __stdcall Cmd(HWND, HWND, wchar_t *data, wchar_t *, BOOL, BOOL)
{
    if (!g_unicode) {
        strcpy_s((char *)data, 16, "error:unicode");
        return 3;
    }
    size_t cap = g_bytes / sizeof(wchar_t);
    if (cap < 128) cap = 128;
    RespondSafe(data, cap);
    return 3;
}

/* ===================================================================================== developer render test
 * cl /DNEONUI_RENDER_TEST ... neonui.cpp  builds an .exe that paints sample icons into PNG files (no mIRC needed).  */
#ifdef NEONUI_RENDER_TEST
#include <shlwapi.h>
static bool SavePng(Gdiplus::Bitmap &bmp, const wchar_t *path)
{
    UINT n = 0, size = 0;
    Gdiplus::GetImageEncodersSize(&n, &size);
    std::vector<char> buf(size);
    Gdiplus::ImageCodecInfo *info = (Gdiplus::ImageCodecInfo *)buf.data();
    Gdiplus::GetImageEncoders(n, size, info);
    for (UINT i = 0; i < n; i++)
        if (wcscmp(info[i].MimeType, L"image/png") == 0) return bmp.Save(path, &info[i].Clsid, nullptr) == Gdiplus::Ok;
    return false;
}

int wmain(int argc, wchar_t **argv)
{
    Gdiplus::GdiplusStartupInput in;
    Gdiplus::GdiplusStartup(&g_gdip, &in, nullptr);
    g_gdipOk = true;
    const wchar_t *out = argc > 1 ? argv[1] : L"render.png";
    Gdiplus::Bitmap sheet(520, 140, PixelFormat32bppARGB);
    {
        Gdiplus::Graphics g(&sheet);
        g.Clear(Gdiplus::Color(255, 0x30, 0x30, 0x38));
        g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
        g.SetTextRenderingHint(Gdiplus::TextRenderingHintAntiAliasGridFit);
        const int counts[5] = { 1, 3, 9, 10, 25 };
        for (int i = 0; i < 5; i++) {                    /* taskbar badges, 16px and enlarged */
            HICON ic = MakeBadge(counts[i]);
            Gdiplus::Bitmap b(ic);
            g.DrawImage(&b, Gdiplus::Rect(10 + i * 50, 10, 16, 16));
            g.DrawImage(&b, Gdiplus::Rect(10 + i * 50, 34, 48, 48));
            DestroyIcon(ic);
        }
        const wchar_t *nicks[6] = { L"Owner", L"Admin", L"Kira", L"Nova", L"zed_", L"[Bot]" };
        for (int i = 0; i < 6; i++) {                    /* avatars and rank icons at 13px and 26px */
            Avatar(g, nicks[i], 270.0f + i * 40, 10, 13);
            Avatar(g, nicks[i], 270.0f + i * 40, 34, 26);
            if (i < 5) RankShape(g, i, 270.0f + i * 40, 70, 11, g_cfg.rankCol[i]);
            if (i < 5) RankShape(g, i, 270.0f + i * 40, 90, 22, g_cfg.rankCol[i]);
        }
    }
    bool ok = SavePng(sheet, out);
    Gdiplus::GdiplusShutdown(g_gdip);
    return ok ? 0 : 1;
}
#endif
