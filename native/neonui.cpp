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
#include <dwmapi.h>
#include <wrl.h>
#include <WebView2.h>
#include <deque>
#include <memory>
#include <mutex>
#include <gdiplus.h>
#include <commctrl.h>
#include <shobjidl.h>
#include <cmath>
#include <cstdlib>
#include <cwchar>
#include <map>
#include <string>
#include <vector>

#define NEONUI_VERSION L"neonui 1.1"

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
    int sizeMode = 0;       /* nick list width: 0 = leave it to mIRC, 1 = fit the longest nickname, 2 = fixed */
    int sizeMin = 110, sizeMax = 240, sizeFixed = 150;
    bool adapt = false;     /* true: drop avatars / icons in narrow lists (windows then differ); false: same look everywhere */
    COLORREF rankCol[5] = { RGB(0xF2, 0xB8, 0x2E), RGB(0xE8, 0x6A, 0x4F), RGB(0x3F, 0xC1, 0x6B), RGB(0x2E, 0xC4, 0xB6), RGB(0x5B, 0x9B, 0xF0) };
};
static Config g_cfg;
static std::map<HWND, bool> g_hooks;
static bool g_sized = false;                           /* we have moved nick list splitters */
static const UINT_PTR HOOK_ID = 0x4E55;     /* "NU" */

static void NlApply(HWND chan, bool force);          /* nick list width, below */
static bool NlWanted() { return g_cfg.rank || g_cfg.avatar || g_cfg.sizeMode; }

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

/* The row's own background colour, read from what mIRC just painted.  A single pixel is not safe - a long nick runs to the
 * edge and the sample lands on a letter (the icon cell then turned into a block of the nick's colour) - so take ten samples
 * along the top and bottom edge of the row, where text does not reach, and use the colour that occurs most often. */
static COLORREF RowBackground(HDC mem, int w, int h)
{
    COLORREF c[10];
    int n = 0;
    if (w < 6 || h < 3) return GetSysColor(COLOR_WINDOW);
    const int xs[5] = { 0, w / 4, w / 2, (3 * w) / 4, w - 1 };
    for (int row = 0; row < 2; row++)
        for (int i = 0; i < 5; i++) {
            COLORREF p = GetPixel(mem, xs[i], row ? h - 1 : 0);
            if (p != CLR_INVALID) c[n++] = p;
        }
    if (!n) return GetSysColor(COLOR_WINDOW);
    int best = 0, bestCount = 0;
    for (int i = 0; i < n; i++) {
        int cnt = 0;
        for (int j = 0; j < n; j++)
            if (c[j] == c[i]) cnt++;
        if (cnt > bestCount) { best = i; bestCount = cnt; }
    }
    return c[best];
}

/* paint one nick list row: mIRC draws it narrower into memory, we copy it right and paint the icons on the left */
static bool DrawNick(HWND chan, WPARAM wp, DRAWITEMSTRUCT *d)
{
    if (!g_gdipOk || (!g_cfg.rank && !g_cfg.avatar)) return false;
    if (d->CtlType != ODT_LISTBOX || (int)d->itemID < 0) return false;
    RECT rc = d->rcItem;
    int W = rc.right - rc.left, H = rc.bottom - rc.top;
    if (H < 11 || W < 48) return false;
    float s = (float)(H - 4);                           /* icon size follows the row height */
    bool wantRank = g_cfg.rank, wantAv = g_cfg.avatar;
    /* optional (off by default, so every channel looks alike): a narrow list keeps room for the names by dropping the
     * avatars first, then the rank icons */
    if (g_cfg.adapt) {
        if (wantRank && wantAv && W < (int)(2 * (s + 3)) + 56) wantAv = false;
        if (wantRank && !wantAv && W < (int)(s + 3) + 40) wantRank = false;
        if (!wantRank && wantAv && W < (int)(s + 3) + 44) wantAv = false;
    }
    if (!wantRank && !wantAv) return false;
    int rankW = wantRank ? (int)(s + 3) : 0;
    int avW = wantAv ? (int)(s + 3) : 0;
    int need = rankW + avW + 1;

    wchar_t txt[96];
    LRESULT want = SendMessageW(d->hwndItem, LB_GETTEXTLEN, d->itemID, 0);   /* never let LB_GETTEXT write past our buffer */
    if (want <= 0 || want >= 96) return false;
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

    COLORREF bg = RowBackground(mem, W - need, H);
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
    } else if (m == WM_SIZE && g_cfg.sizeMode) {
        LRESULT r = DefSubclassProc(h, m, w, l);         /* mIRC lays the window out first, then we put our width back */
        NlApply(h, true);
        return r;
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
    if (g_mirc && NlWanted()) EnumChildWindows(g_mirc, ScanCb, 0);
    if (g_cfg.sizeMode)
        for (auto &kv : g_hooks) NlApply(kv.first, false);
    return (int)g_hooks.size();
}

static void NlRelayout(HWND chan)                      /* make mIRC lay the window out again (its own stored width) */
{
    RECT rc;
    GetClientRect(chan, &rc);
    SendMessageW(chan, WM_SIZE, SIZE_RESTORED, MAKELPARAM(rc.right, rc.bottom));
}

static void UnhookAll()
{
    for (auto &kv : g_hooks) {
        if (IsWindow(kv.first)) {
            if (g_sized) NlRelayout(kv.first);
            RemoveWindowSubclass(kv.first, ChanProc, HOOK_ID);
            HWND list = NickList(kv.first);
            if (list) InvalidateRect(list, nullptr, TRUE);
        }
    }
    g_hooks.clear();
}

/* ===================================================================================== nick list width
 * mIRC keeps a nick list's width per channel window and only changes it when the splitter between the chat text and the list
 * is dragged.  We do exactly what a hand does: press on the splitter, move, release (sent as mouse messages to the channel window). */
struct NlGeo {
    RECT client, list, text;
    bool ok = false, onRight = true;
};

static NlGeo Geometry(HWND chan)
{
    NlGeo g = {};
    HWND l = NickList(chan), t = FindWindowExW(chan, nullptr, L"Static", nullptr);
    if (!l || !t || !IsWindowVisible(l)) return g;
    GetClientRect(chan, &g.client);
    GetWindowRect(l, &g.list);
    GetWindowRect(t, &g.text);
    MapWindowPoints(HWND_DESKTOP, chan, (POINT *)&g.list, 2);
    MapWindowPoints(HWND_DESKTOP, chan, (POINT *)&g.text, 2);
    g.onRight = g.list.left >= g.text.left;
    g.ok = true;
    return g;
}

static int NlWidthNow(HWND chan)
{
    NlGeo g = Geometry(chan);
    return g.ok ? (int)(g.list.right - g.list.left) : -1;
}

/* resize the list and the chat text by hand: the list takes 'want' pixels on its side, the text window gives them up */
static int NlSetWidth(HWND chan, int want)
{
    NlGeo g = Geometry(chan);
    if (!g.ok) return -1;
    int cur = g.list.right - g.list.left;
    if (abs(cur - want) <= 1) return cur;
    int minText = 120;                                          /* never squeeze the chat text below this */
    int avail = (g.client.right - g.client.left) - minText - 8;
    if (want > avail) want = avail;
    if (want < 40) want = 40;
    HWND l = NickList(chan), t = FindWindowExW(chan, nullptr, L"Static", nullptr);
    int listH = g.list.bottom - g.list.top, textH = g.text.bottom - g.text.top;
    int gap = g.onRight ? (g.list.left - g.text.right) : (g.text.left - g.list.right);
    if (g.onRight) {
        int newLeft = g.list.right - want;
        SetWindowPos(l, nullptr, newLeft, g.list.top, want, listH, SWP_NOZORDER | SWP_NOACTIVATE);
        SetWindowPos(t, nullptr, g.text.left, g.text.top, newLeft - gap - g.text.left, textH, SWP_NOZORDER | SWP_NOACTIVATE);
    } else {
        int newRight = g.list.left + want;
        SetWindowPos(l, nullptr, g.list.left, g.list.top, want, listH, SWP_NOZORDER | SWP_NOACTIVATE);
        SetWindowPos(t, nullptr, newRight + gap, g.text.top, g.text.right - (newRight + gap), textH, SWP_NOZORDER | SWP_NOACTIVATE);
    }
    return NlWidthNow(chan);
}

struct NlCache { int count = -1, target = 0; };
static std::map<HWND, NlCache> g_nlCache;

/* how wide the list must be for its longest nickname, the icons and a scroll bar */
static int NlMeasure(HWND list)
{
    int cnt = (int)SendMessageW(list, LB_GETCOUNT, 0, 0);
    if (cnt <= 0) return 0;
    HDC dc = GetDC(list);
    if (!dc) return 0;
    HFONT f = (HFONT)SendMessageW(list, WM_GETFONT, 0, 0);
    HGDIOBJ old = f ? SelectObject(dc, f) : nullptr;
    int best = 0;
    wchar_t t[96];
    for (int i = 0; i < cnt; i++) {
        LRESULT len = SendMessageW(list, LB_GETTEXTLEN, i, 0);
        if (len <= 0 || len >= 96) continue;
        if (SendMessageW(list, LB_GETTEXT, i, (LPARAM)t) <= 0) continue;
        SIZE sz;
        if (GetTextExtentPoint32W(dc, t, (int)len, &sz) && sz.cx > best) best = sz.cx;
    }
    if (old) SelectObject(dc, old);
    ReleaseDC(list, dc);
    int rowH = (int)SendMessageW(list, LB_GETITEMHEIGHT, 0, 0);
    if (rowH <= 0) rowH = 15;
    RECT rc;
    GetClientRect(list, &rc);
    bool vscroll = (long)cnt * rowH > rc.bottom;
    float s = (float)(rowH - 4);
    int icons = (g_cfg.rank ? (int)(s + 3) : 0) + (g_cfg.avatar ? (int)(s + 3) : 0) + ((g_cfg.rank || g_cfg.avatar) ? 1 : 0);
    return best + icons + 12 + (vscroll ? GetSystemMetrics(SM_CXVSCROLL) : 0);
}

/* put the nick list of one channel window at the configured width (re-measured when its number of nicknames changed) */
static void NlApply(HWND chan, bool force)
{
    static bool busy = false;
    if (!g_cfg.sizeMode || busy) return;
    if (GetAsyncKeyState(VK_LBUTTON) & 0x8000) return;            /* never fight a drag in progress */
    HWND l = NickList(chan);
    if (!l || !IsWindowVisible(l)) return;
    int target;
    if (g_cfg.sizeMode == 2) {
        target = g_cfg.sizeFixed;
    } else {
        NlCache &c = g_nlCache[chan];
        int cnt = (int)SendMessageW(l, LB_GETCOUNT, 0, 0);
        if (c.count != cnt || c.target <= 0) {
            c.count = cnt;
            c.target = NlMeasure(l);
        }
        target = c.target;
        if (target <= 0) return;
    }
    target = max(g_cfg.sizeMin, min(g_cfg.sizeMax, target));
    if (abs(NlWidthNow(chan) - target) <= 1) return;
    busy = true;
    NlSetWidth(chan, target);
    g_sized = true;
    busy = false;
    (void)force;
}

static std::wstring NlInfo()
{
    std::wstring out;
    for (auto &kv : g_hooks) {
        NlGeo g = Geometry(kv.first);
        wchar_t b[200];
        if (!g.ok) { swprintf(b, 200, L"%p none;", (void *)kv.first); out += b; continue; }
        swprintf(b, 200, L"%p client=%dx%d list=%d,%d,%d,%d text=%d,%d,%d,%d right=%d;", (void *)kv.first,
                 (int)(g.client.right - g.client.left), (int)(g.client.bottom - g.client.top), (int)g.list.left, (int)g.list.top,
                 (int)(g.list.right - g.list.left), (int)(g.list.bottom - g.list.top), (int)g.text.left, (int)g.text.top,
                 (int)(g.text.right - g.text.left), (int)(g.text.bottom - g.text.top), g.onRight ? 1 : 0);
        out += b;
    }
    return out;
}

/* ===================================================================================== menu items
 * mIRC has no command for some of its own windows (the Favorites folder is only in the Favorites menu: Manage Favorites, Alt+J).  This presses a
 * menu item of mIRC's menu bar by its text - only the few items NeonScript names below. */
static bool MenuTextIs(HMENU m, int pos, const wchar_t *want)
{
    wchar_t buf[128];
    int n = GetMenuStringW(m, pos, buf, 128, MF_BYPOSITION);
    if (n <= 0) return false;
    std::wstring t;
    for (int i = 0; i < n && buf[i] != L'\t'; i++)
        if (buf[i] != L'&') t += (wchar_t)towlower(buf[i]);
    while (!t.empty() && (t.back() == L'.' || t.back() == L' ')) t.pop_back();
    return t == want;
}

static bool FindMenuItem(HMENU m, const wchar_t *want, UINT *id, int depth)
{
    int n = GetMenuItemCount(m);
    for (int i = 0; i < n; i++) {
        HMENU sub = GetSubMenu(m, i);
        if (sub) {
            if (depth < 4 && FindMenuItem(sub, want, id, depth + 1)) return true;
            continue;
        }
        if (MenuTextIs(m, i, want)) {
            UINT st = GetMenuState(m, i, MF_BYPOSITION);
            UINT mid = GetMenuItemID(m, i);
            if (mid == (UINT)-1 || mid == 0 || (st & (MF_GRAYED | MF_DISABLED))) return false;
            *id = mid;
            return true;
        }
    }
    return false;
}

/* what is in mIRC's menu bar (for finding out why an item cannot be pressed) */
static void ListMenu(HMENU m, int depth, std::wstring &out)
{
    int n = GetMenuItemCount(m);
    for (int i = 0; i < n && out.size() < 3000; i++) {
        wchar_t buf[64];
        int len = GetMenuStringW(m, i, buf, 64, MF_BYPOSITION);
        MENUITEMINFOW mi = { sizeof(mi) };
        mi.fMask = MIIM_FTYPE | MIIM_ID;
        GetMenuItemInfoW(m, i, TRUE, &mi);
        out += std::wstring(depth * 2, L' ') + (len > 0 ? std::wstring(buf, len) : L"?") + L" [" + std::to_wstring(mi.wID) + L"/" + std::to_wstring(mi.fType) + L"];";
        HMENU sub = GetSubMenu(m, i);
        if (sub && depth < 2) ListMenu(sub, depth + 1, out);
    }
}

static std::wstring PressMenu(const std::wstring &which)
{
    static const wchar_t *allowed[] = { L"manage favorites" };
    std::wstring w;
    for (wchar_t c : which) w += (wchar_t)towlower(c);
    bool ok = false;
    for (const wchar_t *a : allowed)
        if (w == a) ok = true;
    if (!ok) return L"error:not allowed";
    HMENU bar = g_mirc ? GetMenu(g_mirc) : nullptr;
    if (!bar) return L"error:no menu bar";
    UINT id = 0;
    if (!FindMenuItem(bar, w.c_str(), &id, 0)) return L"error:no such menu item";
    PostMessageW(g_mirc, WM_COMMAND, MAKEWPARAM(id, 0), 0);
    return L"ok";
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

/* ===================================================================================== panels (WebView2)
 * HTML panels (emoji picker, rich cards ...) shown in small windows of their own.  Everything runs on one helper thread
 * (apartment threaded, with a message loop) so mIRC's own thread is never blocked: the exported commands only queue work and
 * return.  Pages come from NeonScript's data\ui folder, mapped to https://neon.local/ - nothing else may be loaded: any other
 * navigation is cancelled (links are handed to NeonScript as events instead), new windows, downloads and permission
 * requests are refused.  What a page sends with chrome.webview.postMessage() is queued as text; NeonScript fetches it with
 * "wvpoll" and treats it as untrusted data.
 */
using Microsoft::WRL::Callback;
using Microsoft::WRL::ComPtr;

static std::mutex g_mx;                                  /* guards the two queues below */
static std::deque<std::wstring> g_cmds;                  /* mIRC thread -> panel thread: "verb<TAB>args" */
static std::deque<std::wstring> g_events;                /* panel thread -> mIRC:  "panel<TAB>kind<TAB>text" */
static HANDLE g_thread = nullptr;
static DWORD g_threadId = 0;
static HANDLE g_threadUp = nullptr;
static std::wstring g_userData, g_uiDir;
static bool g_testJs = false;                            /* wveval only works when NEONUI_TEST is set in the environment */

struct Panel {
    std::wstring name;
    HWND hwnd = nullptr;
    ComPtr<ICoreWebView2Controller> ctl;
    ComPtr<ICoreWebView2> wv;
    std::wstring page;
    std::vector<std::wstring> pending;                  /* posts that arrived before the page was ready */
    COLORREF bg = RGB(16, 16, 24);
    bool debug = false;
    bool loaded = false;
};
static std::map<std::wstring, std::shared_ptr<Panel>> g_panels;      /* panel thread only */
static ComPtr<ICoreWebView2Environment> g_env;
static bool g_envAsked = false, g_envFailed = false;
static const wchar_t *PANEL_CLASS = L"NeonUiPanel";
static const wchar_t *HOST = L"neon.local";
static const UINT WM_NU_WORK = WM_APP + 1;

static void PushEvent(const std::wstring &panel, const wchar_t *kind, const std::wstring &text)
{
    std::wstring t = text.size() > 3000 ? text.substr(0, 3000) : text;
    for (auto &c : t)
        if (c == L'\t' || c == L'\r' || c == L'\n') c = L' ';
    std::lock_guard<std::mutex> lk(g_mx);
    if (g_events.size() < 500) g_events.push_back(panel + L"\t" + kind + L"\t" + t);
}

static std::wstring Hr(HRESULT hr)
{
    wchar_t b[24];
    swprintf(b, 24, L"0x%08X", (unsigned)hr);
    return b;
}

static void ApplyDark(HWND h, bool dark)
{
    BOOL v = dark ? TRUE : FALSE;
    DwmSetWindowAttribute(h, 20 /* DWMWA_USE_IMMERSIVE_DARK_MODE */, &v, sizeof(v));
}

static void FitPanel(Panel &p)
{
    if (!p.ctl || !p.hwnd) return;
    RECT rc;
    GetClientRect(p.hwnd, &rc);
    p.ctl->put_Bounds(rc);
}

static LRESULT CALLBACK PanelProc(HWND h, UINT m, WPARAM w, LPARAM l)
{
    Panel *p = (Panel *)GetWindowLongPtrW(h, GWLP_USERDATA);
    switch (m) {
    case WM_NCCREATE:
        SetWindowLongPtrW(h, GWLP_USERDATA, (LONG_PTR)((CREATESTRUCTW *)l)->lpCreateParams);
        break;
    case WM_SIZE:
        if (p) FitPanel(*p);
        return 0;
    case WM_ERASEBKGND:
        if (p && !p->loaded) {                          /* no white flash while the page loads */
            HBRUSH b = CreateSolidBrush(p->bg);
            RECT rc;
            GetClientRect(h, &rc);
            FillRect((HDC)w, &rc, b);
            DeleteObject(b);
        }
        return 1;
    case WM_CLOSE:
        if (p) {
            std::wstring name = p->name;
            std::shared_ptr<Panel> keep = g_panels[name];     /* keep the panel alive while its window goes away */
            PushEvent(name, L"closed", L"");
            if (keep && keep->ctl) keep->ctl->Close();
            g_panels.erase(name);
            SetWindowLongPtrW(h, GWLP_USERDATA, 0);
            DestroyWindow(h);
        } else {
            DestroyWindow(h);
        }
        return 0;
    }
    return DefWindowProcW(h, m, w, l);
}

static void SetupPanel(const std::shared_ptr<Panel> &p)
{
    ComPtr<ICoreWebView2Settings> st;
    if (SUCCEEDED(p->wv->get_Settings(&st)) && st) {
        st->put_AreDefaultContextMenusEnabled(p->debug ? TRUE : FALSE);
        st->put_AreDevToolsEnabled(p->debug ? TRUE : FALSE);
        st->put_AreDefaultScriptDialogsEnabled(FALSE);
        st->put_IsStatusBarEnabled(FALSE);
        st->put_IsZoomControlEnabled(FALSE);
        st->put_IsBuiltInErrorPageEnabled(FALSE);
        ComPtr<ICoreWebView2Settings3> s3;
        if (SUCCEEDED(st.As(&s3))) s3->put_AreBrowserAcceleratorKeysEnabled(p->debug ? TRUE : FALSE);
        ComPtr<ICoreWebView2Settings4> s4;
        if (SUCCEEDED(st.As(&s4))) {
            s4->put_IsPasswordAutosaveEnabled(FALSE);
            s4->put_IsGeneralAutofillEnabled(FALSE);
        }
    }
    ComPtr<ICoreWebView2Controller2> c2;
    if (SUCCEEDED(p->ctl.As(&c2))) {
        COREWEBVIEW2_COLOR col = { 255, GetRValue(p->bg), GetGValue(p->bg), GetBValue(p->bg) };
        c2->put_DefaultBackgroundColor(col);
    }
    ComPtr<ICoreWebView2_3> w3;
    if (SUCCEEDED(p->wv.As(&w3)))
        w3->SetVirtualHostNameToFolderMapping(HOST, g_uiDir.c_str(), COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_DENY_CORS);

    std::weak_ptr<Panel> wp = p;
    EventRegistrationToken tok;
    p->wv->add_NavigationStarting(Callback<ICoreWebView2NavigationStartingEventHandler>(
        [wp](ICoreWebView2 *, ICoreWebView2NavigationStartingEventArgs *a) -> HRESULT {
            auto p = wp.lock();
            LPWSTR uri = nullptr;
            a->get_Uri(&uri);
            std::wstring u = uri ? uri : L"";
            if (uri) CoTaskMemFree(uri);
            if (u.compare(0, 19, L"https://neon.local/") != 0 && u != L"about:blank") {
                a->put_Cancel(TRUE);
                if (p && (u.compare(0, 7, L"http://") == 0 || u.compare(0, 8, L"https://") == 0)) PushEvent(p->name, L"link", u);
            }
            return S_OK;
        }).Get(), &tok);
    p->wv->add_NewWindowRequested(Callback<ICoreWebView2NewWindowRequestedEventHandler>(
        [wp](ICoreWebView2 *, ICoreWebView2NewWindowRequestedEventArgs *a) -> HRESULT {
            a->put_Handled(TRUE);
            auto p = wp.lock();
            LPWSTR uri = nullptr;
            a->get_Uri(&uri);
            if (p && uri) PushEvent(p->name, L"link", uri);
            if (uri) CoTaskMemFree(uri);
            return S_OK;
        }).Get(), &tok);
    p->wv->add_WebMessageReceived(Callback<ICoreWebView2WebMessageReceivedEventHandler>(
        [wp](ICoreWebView2 *, ICoreWebView2WebMessageReceivedEventArgs *a) -> HRESULT {
            auto p = wp.lock();
            LPWSTR s = nullptr;
            if (p && SUCCEEDED(a->TryGetWebMessageAsString(&s)) && s) PushEvent(p->name, L"msg", s);
            if (s) CoTaskMemFree(s);
            return S_OK;
        }).Get(), &tok);
    p->wv->add_PermissionRequested(Callback<ICoreWebView2PermissionRequestedEventHandler>(
        [](ICoreWebView2 *, ICoreWebView2PermissionRequestedEventArgs *a) -> HRESULT {
            a->put_State(COREWEBVIEW2_PERMISSION_STATE_DENY);
            return S_OK;
        }).Get(), &tok);
    ComPtr<ICoreWebView2_4> w4;
    if (SUCCEEDED(p->wv.As(&w4)))
        w4->add_DownloadStarting(Callback<ICoreWebView2DownloadStartingEventHandler>(
            [](ICoreWebView2 *, ICoreWebView2DownloadStartingEventArgs *a) -> HRESULT {
                a->put_Cancel(TRUE);
                return S_OK;
            }).Get(), &tok);
    p->wv->add_NavigationCompleted(Callback<ICoreWebView2NavigationCompletedEventHandler>(
        [wp](ICoreWebView2 *, ICoreWebView2NavigationCompletedEventArgs *a) -> HRESULT {
            auto p = wp.lock();
            if (!p) return S_OK;
            BOOL ok = FALSE;
            a->get_IsSuccess(&ok);
            if (!p->loaded && ok) {
                p->loaded = true;
                for (auto &t : p->pending) p->wv->PostWebMessageAsString(t.c_str());
                p->pending.clear();
            }
            PushEvent(p->name, ok ? L"loaded" : L"loadfailed", p->page);
            return S_OK;
        }).Get(), &tok);

    FitPanel(*p);
    p->ctl->put_IsVisible(TRUE);
    std::wstring url = std::wstring(L"https://") + HOST + L"/" + p->page;
    p->wv->Navigate(url.c_str());
}

static void StartController(const std::shared_ptr<Panel> &p)
{
    std::weak_ptr<Panel> wp = p;
    HRESULT hr = g_env->CreateCoreWebView2Controller(p->hwnd, Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
        [wp](HRESULT r, ICoreWebView2Controller *c) -> HRESULT {
            auto p = wp.lock();
            if (!p) {
                if (c) c->Close();
                return S_OK;
            }
            if (FAILED(r) || !c) {
                PushEvent(p->name, L"error", L"controller " + Hr(r));
                return S_OK;
            }
            p->ctl = c;
            c->get_CoreWebView2(&p->wv);
            if (!p->wv) {
                PushEvent(p->name, L"error", L"no core");
                return S_OK;
            }
            SetupPanel(p);
            return S_OK;
        }).Get());
    if (FAILED(hr)) PushEvent(p->name, L"error", L"controller " + Hr(hr));
}

static void EnsureEnv()
{
    if (g_env || g_envAsked) return;
    g_envAsked = true;
    HRESULT hr = CreateCoreWebView2EnvironmentWithOptions(nullptr, g_userData.c_str(), nullptr,
        Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
            [](HRESULT r, ICoreWebView2Environment *env) -> HRESULT {
                if (FAILED(r) || !env) {
                    g_envFailed = true;
                    PushEvent(L"*", L"error", L"environment " + Hr(r));
                    return S_OK;
                }
                g_env = env;
                std::vector<std::shared_ptr<Panel>> todo;
                for (auto &kv : g_panels)
                    if (!kv.second->ctl) todo.push_back(kv.second);
                for (auto &p : todo) StartController(p);
                return S_OK;
            }).Get());
    if (FAILED(hr)) {
        g_envFailed = true;
        PushEvent(L"*", L"error", L"environment " + Hr(hr));
    }
}

static void OpenPanel(const std::vector<std::wstring> &a)
{
    /* wvopen <name> <page> <width> <height> <title> <flags> */
    if (a.size() < 7) return;
    const std::wstring &name = a[1];
    auto it = g_panels.find(name);
    if (it != g_panels.end()) {                          /* already open: bring it forward */
        ShowWindow(it->second->hwnd, SW_SHOWNORMAL);
        SetForegroundWindow(it->second->hwnd);
        return;
    }
    if (g_envFailed) {
        PushEvent(name, L"error", L"the WebView2 runtime is not available");
        return;
    }
    auto p = std::make_shared<Panel>();
    p->name = name;
    p->page = a[2];
    int w = max(240, min(1400, _wtoi(a[3].c_str()))), h = max(160, min(1000, _wtoi(a[4].c_str())));
    const std::wstring &fl = a[6];
    p->debug = fl.find(L"debug") != std::wstring::npos;
    size_t bp = fl.find(L"bg=");
    if (bp != std::wstring::npos && fl.size() >= bp + 9) p->bg = HexColour(fl.substr(bp + 3, 6), p->bg);
    bool dark = fl.find(L"dark") != std::wstring::npos;
    RECT mr = { 100, 100, 900, 700 };
    if (g_mirc) GetWindowRect(g_mirc, &mr);
    int x = mr.left + max(0, (int)((mr.right - mr.left) - w) / 2), y = mr.top + max(0, (int)((mr.bottom - mr.top) - h) / 3);
    DWORD ex = (fl.find(L"top") != std::wstring::npos) ? WS_EX_TOPMOST : 0;
    HWND hw = CreateWindowExW(ex, PANEL_CLASS, a[5].c_str(), WS_OVERLAPPEDWINDOW, x, y, w, h, nullptr, nullptr, g_self, p.get());
    if (!hw) {
        PushEvent(name, L"error", L"window " + Hr(HRESULT_FROM_WIN32(GetLastError())));
        return;
    }
    p->hwnd = hw;
    ApplyDark(hw, dark);
    g_panels[name] = p;
    ShowWindow(hw, SW_SHOWNORMAL);
    UpdateWindow(hw);
    EnsureEnv();
    if (g_env) StartController(p);
}

static void DoCommand(const std::wstring &cmd)
{
    std::vector<std::wstring> a = Split(cmd, L'\t');
    const std::wstring &v = a[0];
    if (v == L"wvopen") {
        OpenPanel(a);
        return;
    }
    if (v == L"wvcloseall") {
        std::vector<HWND> all;
        for (auto &kv : g_panels) all.push_back(kv.second->hwnd);
        for (HWND h : all) PostMessageW(h, WM_CLOSE, 0, 0);
        return;
    }
    if (a.size() < 2) return;
    auto it = g_panels.find(a[1]);
    if (it == g_panels.end()) return;
    std::shared_ptr<Panel> p = it->second;
    std::wstring rest;                                   /* everything after the second TAB (text may contain TABs) */
    {
        size_t t1 = cmd.find(L'\t');
        size_t t2 = t1 == std::wstring::npos ? t1 : cmd.find(L'\t', t1 + 1);
        if (t2 != std::wstring::npos) rest = cmd.substr(t2 + 1);
    }
    if (v == L"wvclose") {
        PostMessageW(p->hwnd, WM_CLOSE, 0, 0);
    } else if (v == L"wvpost" && a.size() > 2) {
        if (p->loaded && p->wv) p->wv->PostWebMessageAsString(rest.c_str());
        else if (p->pending.size() < 20) p->pending.push_back(rest);
    } else if (v == L"wvtitle" && a.size() > 2) {
        SetWindowTextW(p->hwnd, rest.c_str());
    } else if (v == L"wveval" && a.size() > 2 && g_testJs && p->wv) {
        std::wstring name = p->name;
        p->wv->ExecuteScript(rest.c_str(), Callback<ICoreWebView2ExecuteScriptCompletedHandler>(
            [name](HRESULT r, LPCWSTR res) -> HRESULT {
                PushEvent(name, L"eval", FAILED(r) ? L"error " + Hr(r) : std::wstring(res ? res : L""));
                return S_OK;
            }).Get());
    }
}

static DWORD WINAPI PanelThread(LPVOID)
{
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    WNDCLASSEXW wc = { sizeof(wc) };
    wc.lpfnWndProc = PanelProc;
    wc.hInstance = g_self;
    wc.lpszClassName = PANEL_CLASS;
    wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
    wc.hIcon = LoadIcon(nullptr, IDI_APPLICATION);
    RegisterClassExW(&wc);
    MSG msg;
    PeekMessageW(&msg, nullptr, WM_USER, WM_USER, PM_NOREMOVE);      /* creates this thread's message queue */
    SetEvent(g_threadUp);
    while (GetMessageW(&msg, nullptr, 0, 0) > 0) {
        if (msg.hwnd == nullptr && msg.message == WM_NU_WORK) {
            for (;;) {
                std::wstring c;
                {
                    std::lock_guard<std::mutex> lk(g_mx);
                    if (g_cmds.empty()) break;
                    c = g_cmds.front();
                    g_cmds.pop_front();
                }
                try {
                    DoCommand(c);
                } catch (...) {
                }
            }
            continue;
        }
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }
    for (auto &kv : g_panels) {
        if (kv.second->ctl) kv.second->ctl->Close();
        if (kv.second->hwnd) DestroyWindow(kv.second->hwnd);
    }
    g_panels.clear();
    g_env.Reset();
    UnregisterClassW(PANEL_CLASS, g_self);
    CoUninitialize();
    return 0;
}

static std::wstring PanelInit(const std::vector<std::wstring> &a)
{
    /* wvinit <user data folder> <ui folder> */
    if (a.size() < 3) return L"error:arguments";
    LPWSTR ver = nullptr;
    HRESULT hr = GetAvailableCoreWebView2BrowserVersionString(nullptr, &ver);
    if (FAILED(hr) || !ver) return L"error:no WebView2 runtime";
    std::wstring v = ver;
    CoTaskMemFree(ver);
    if (!g_thread) {
        g_userData = a[1];
        g_uiDir = a[2];
        wchar_t env[8];
        g_testJs = GetEnvironmentVariableW(L"NEONUI_TEST", env, 8) > 0;
        g_threadUp = CreateEventW(nullptr, TRUE, FALSE, nullptr);
        g_thread = CreateThread(nullptr, 0, PanelThread, nullptr, 0, &g_threadId);
        if (!g_thread) return L"error:thread";
        WaitForSingleObject(g_threadUp, 5000);
    }
    return L"ok " + v;
}

static void QueueCommand(const std::wstring &c)
{
    if (!g_thread) return;
    {
        std::lock_guard<std::mutex> lk(g_mx);
        if (g_cmds.size() < 200) g_cmds.push_back(c);
    }
    PostThreadMessageW(g_threadId, WM_NU_WORK, 0, 0);
}

static std::wstring PollEvent()
{
    std::lock_guard<std::mutex> lk(g_mx);
    if (g_events.empty()) return L"";
    std::wstring e = g_events.front();
    g_events.pop_front();
    return e;
}

static void PanelShutdown()
{
    if (!g_thread) return;
    PostThreadMessageW(g_threadId, WM_QUIT, 0, 0);
    WaitForSingleObject(g_thread, 4000);
    CloseHandle(g_thread);
    g_thread = nullptr;
    if (g_threadUp) {
        CloseHandle(g_threadUp);
        g_threadUp = nullptr;
    }
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
        g_cfg.adapt = Opt(a, L"auto", L"0") == L"1";
        static const wchar_t *keys[5] = { L"q", L"a", L"o", L"h", L"v" };
        for (int i = 0; i < 5; i++) g_cfg.rankCol[i] = HexColour(Opt(a, keys[i]), g_cfg.rankCol[i]);
        {
            std::wstring sz = Opt(a, L"size", L"off");
            int oldMode = g_cfg.sizeMode;
            g_cfg.sizeMode = sz == L"auto" ? 1 : (sz == L"fixed" ? 2 : 0);
            g_cfg.sizeMin = max(60, min(400, _wtoi(Opt(a, L"min", L"110").c_str())));
            g_cfg.sizeMax = max(g_cfg.sizeMin, min(500, _wtoi(Opt(a, L"max", L"240").c_str())));
            g_cfg.sizeFixed = max(60, min(500, _wtoi(Opt(a, L"fixed", L"150").c_str())));
            if (oldMode && !g_cfg.sizeMode && g_sized) {
                for (auto &kv : g_hooks) if (IsWindow(kv.first)) NlRelayout(kv.first);     /* give mIRC's own widths back */
                g_sized = false;
            }
            g_nlCache.clear();
        }
        if (!NlWanted()) UnhookAll();
        else { NickScan(); Repaint(); }
        return L"ok";
    }
    if (v == L"wvinit") return PanelInit(a);
    if (v == L"wvpoll") return PollEvent();
    if (v == L"wvopen" || v == L"wvpost" || v == L"wvclose" || v == L"wvcloseall" || v == L"wvtitle" || v == L"wveval") {
        if (!g_thread) return L"error:not initialised";
        QueueCommand(in);
        return L"ok";
    }
    if (v == L"menuitem") return PressMenu(a.size() > 1 ? a[1] : L"");
    if (v == L"menulist") { std::wstring o; HMENU bar = g_mirc ? GetMenu(g_mirc) : nullptr; if (bar) ListMenu(bar, 0, o); else o = L"no menu bar"; return o; }
    if (v == L"nlinfo") return NlInfo();
    if (v == L"nlwidth") {
        int want = a.size() > 1 ? _wtoi(a[1].c_str()) : 0, n = 0;
        std::wstring out;
        for (auto &kv : g_hooks) { int w = NlSetWidth(kv.first, want); out += std::to_wstring(w) + L" "; n++; }
        return out;
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
    PanelShutdown();
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
