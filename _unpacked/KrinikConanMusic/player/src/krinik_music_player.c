/*
 * krinik_music_player.c — the player of KrinikConanMusic (KUMM plan 46).
 *
 * Why a separate process: the game thread of Conan has a 1 ms budget for ALL our mods (MASTER_PLAN), and decoding mp3/ogg/flac costs far more.
 * The Lua half of the mod (Scripts/main.lua) only decides the scene on the game's own events and writes State/state.json; this process plays.
 * The split — Lua detector -> state.json -> native player — is the design of Palworld «Area specific background Music» (Nexus palworld/4679); its
 * player is a UE4SS C++ mod without source, tied to another UE4SS build, so ours is a plain program (no UE4SS ABI), like M4 Music's external host.
 *
 * Protocol (all files in <mod>\State\):
 *   state.json  (written by Lua, temp + rename): {"seq":N,"scene":"combat_hard","folders":["combat_hard","combat"],"volume":0.80,"active":true,"quit":false}
 *               folders — the fallback chain: the FIRST folder of music\ that holds audio files plays; none — silence (the game's own music stays).
 *   player.json (written here on every change): {"pid":P,"playing":true,"folder":"combat","file":"x.mp3","title":"x","started":T,"inventory":{"combat":2,...}}
 *               inventory — audio files per folder of music\ (Lua mutes the game's music only where our folder is not empty);
 *               the future «now playing» HUD widget (the owner's groundwork word, 2026-11-06 17:37) reads title/started from here.
 * Per folder, optional: playlist.txt — one file name per line: listed files only, in that order; a line "-name" excludes a file.
 * music\track_gains.txt — "file.mp3|0.5" per line (Palworld's format).
 * Behaviour: random track per entry (never the same twice in a row), crossfade, a 60 s grace period (a folder left and re-entered within it RESUMES),
 * the next track when one ends, exit when the game process ends or state.json says quit.
 *
 * Build: build_player.cmd (MSVC). [TESTED: 2026-11-06 · stand P0-P7 pass with real output (peak 0.22), report KUMM testcases/reports/2026-11-06_conan-music-player-stand.md; not yet with the game]
 */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#include <tlhelp32.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>
#include <time.h>

#define STB_VORBIS_HEADER_ONLY
#include "../vendor/stb_vorbis.c"
#define MINIAUDIO_IMPLEMENTATION
#define MA_NO_ENCODING
#define MA_NO_GENERATION
#include "../vendor/miniaudio.h"
#undef STB_VORBIS_HEADER_ONLY
#include "../vendor/stb_vorbis.c"
/* stb_vorbis leaves its channel macros L, C, R defined — L breaks every wide literal L"…" below (MSVC: «missing ')' before string», 2026-11-06). */
#undef L
#undef C
#undef R

#define TICK_MS            50      /* main loop step: volume ramps, end-of-track, state polling */
#define STATE_POLL_MS      200     /* how often state.json's time stamp is looked at */
#define RESCAN_MS          5000    /* how often music\ is re-listed (tracks added while the game runs) */
#define FADE_IN_MS         2500
#define FADE_OUT_MS        2500
#define GRACE_MS           60000   /* a folder re-entered within this resumes instead of restarting (Palworld's grace period) */
#define MAX_FOLDERS        128
#define MAX_TRACKS         512
#define MAX_CHAIN          8
#define MAX_VOICES         4       /* the current voice + the ones fading out / waiting in the grace period */
#define MAX_PROCS          4096
#define GAME_EXE           L"ConanSandbox-Win64-Shipping.exe"

typedef struct { wchar_t name[64]; int count; } Folder;
typedef struct {
    int used; ma_sound snd; wchar_t folder[64]; wchar_t file[MAX_PATH];
    float vol, target, step, gain; DWORD left_at; int paused; time_t started;
} Voice;

static wchar_t g_mod[MAX_PATH], g_music[MAX_PATH], g_state_dir[MAX_PATH];
static FILE *g_log;
static ma_engine g_engine;
static Folder g_folders[MAX_FOLDERS]; static int g_nfolders;
static Voice g_v[MAX_VOICES]; static int g_cur = -1;
static wchar_t g_last_file[MAX_PATH];
static float g_volume = 1.0f; static int g_active = 0;
static wchar_t g_chain[MAX_CHAIN][64]; static int g_nchain;
static int g_dirty = 1;
static wchar_t g_tracks[MAX_TRACKS][MAX_PATH];   /* scratch list, one user at a time (single thread) */

static void logw(const char *fmt, ...) {
    if (!g_log) return;
    SYSTEMTIME t; GetLocalTime(&t);
    fprintf(g_log, "[%02d:%02d:%02d.%03d] ", t.wHour, t.wMinute, t.wSecond, t.wMilliseconds);
    va_list ap; va_start(ap, fmt); vfprintf(g_log, fmt, ap); va_end(ap);
    fputc('\n', g_log); fflush(g_log);
}

static void to_utf8(const wchar_t *w, char *out, int n) { WideCharToMultiByte(CP_UTF8, 0, w, -1, out, n, NULL, NULL); }
static void from_utf8(const char *s, wchar_t *out, int n) { MultiByteToWideChar(CP_UTF8, 0, s, -1, out, n); }

static int is_audio(const wchar_t *f) {
    const wchar_t *e = wcsrchr(f, L'.');
    return e && (!_wcsicmp(e, L".mp3") || !_wcsicmp(e, L".ogg") || !_wcsicmp(e, L".flac") || !_wcsicmp(e, L".wav"));
}

/* Lists the audio files of one folder, honouring its playlist.txt. Returns the count; names into out. */
static int list_tracks(const wchar_t *folder, wchar_t out[][MAX_PATH], int max) {
    wchar_t pat[MAX_PATH]; int n = 0;
    static wchar_t excl[64][MAX_PATH]; int nex = 0;
    _snwprintf(pat, MAX_PATH, L"%s\\%s\\playlist.txt", g_music, folder);
    FILE *pl = _wfopen(pat, L"rb");
    if (pl) {
        char line[1024];
        while (fgets(line, sizeof line, pl)) {
            char *s = line; if ((unsigned char)s[0] == 0xEF) s += 3;         /* UTF-8 BOM */
            s[strcspn(s, "\r\n")] = 0; if (!*s || *s == '#') continue;
            wchar_t w[MAX_PATH]; from_utf8(*s == '-' ? s + 1 : s, w, MAX_PATH);
            if (*s == '-') { if (nex < 64) wcscpy(excl[nex++], w); continue; }
            if (n < max && is_audio(w)) wcscpy(out[n++], w);
        }
        fclose(pl);
        if (n) return n;                                                     /* listed files only, in that order */
    }
    _snwprintf(pat, MAX_PATH, L"%s\\%s\\*", g_music, folder);
    WIN32_FIND_DATAW fd; HANDLE h = FindFirstFileW(pat, &fd);
    if (h == INVALID_HANDLE_VALUE) return 0;
    do {
        if ((fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) || !is_audio(fd.cFileName)) continue;
        int skip = 0; for (int i = 0; i < nex; i++) if (!_wcsicmp(excl[i], fd.cFileName)) skip = 1;
        if (!skip && n < max) wcscpy(out[n++], fd.cFileName);
    } while (FindNextFileW(h, &fd));
    FindClose(h);
    return n;
}

static void rescan(void) {
    wchar_t pat[MAX_PATH]; _snwprintf(pat, MAX_PATH, L"%s\\*", g_music);
    WIN32_FIND_DATAW fd; HANDLE h = FindFirstFileW(pat, &fd);
    int n = 0;
    if (h != INVALID_HANDLE_VALUE) {
        do {
            if (!(fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) || fd.cFileName[0] == L'.' || n >= MAX_FOLDERS) continue;
            int c = list_tracks(fd.cFileName, g_tracks, MAX_TRACKS);
            if (c != g_folders[n].count || wcscmp(g_folders[n].name, fd.cFileName)) g_dirty = 1;
            wcsncpy(g_folders[n].name, fd.cFileName, 63); g_folders[n].name[63] = 0;
            g_folders[n].count = c; n++;
        } while (FindNextFileW(h, &fd));
        FindClose(h);
    }
    if (n != g_nfolders) g_dirty = 1;
    g_nfolders = n;
}

static int folder_count(const wchar_t *name) {
    for (int i = 0; i < g_nfolders; i++) if (!_wcsicmp(g_folders[i].name, name)) return g_folders[i].count;
    return 0;
}

static float track_gain(const wchar_t *file) {
    wchar_t p[MAX_PATH]; _snwprintf(p, MAX_PATH, L"%s\\track_gains.txt", g_music);
    FILE *f = _wfopen(p, L"rb"); if (!f) return 1.0f;
    char line[1024], want[MAX_PATH * 3]; to_utf8(file, want, sizeof want); float g = 1.0f;
    while (fgets(line, sizeof line, f)) {
        char *bar = strchr(line, '|'); if (!bar) continue; *bar = 0;
        char *s = line; if ((unsigned char)s[0] == 0xEF) s += 3;
        if (!_stricmp(s, want)) { g = (float)atof(bar + 1); break; }
    }
    fclose(f);
    return g > 0 ? g : 1.0f;
}

/* ---------- the tiny reader of our own state.json (a fixed format written by our Lua) ---------- */
static const char *jfind(const char *j, const char *key) {
    char k[64]; _snprintf(k, sizeof k, "\"%s\"", key);
    const char *p = strstr(j, k); if (!p) return NULL;
    p = strchr(p + strlen(k), ':'); if (!p) return NULL;
    p++; while (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n') p++;  /* «"active": true» — a writer may put a space (Python json.dumps did, 2026-11-06) */
    return p;
}
static const char *jstr(const char *p, char *out, int n) {   /* returns the char after the closing quote, or NULL */
    while (*p == ' ') p++; if (*p != '"') return NULL; p++;
    int i = 0; while (*p && *p != '"' && i < n - 1) out[i++] = *p++;
    out[i] = 0; return *p == '"' ? p + 1 : NULL;
}

static void read_state(void) {
    wchar_t p[MAX_PATH]; _snwprintf(p, MAX_PATH, L"%s\\state.json", g_state_dir);
    FILE *f = _wfopen(p, L"rb"); if (!f) return;
    char j[4096]; size_t n = fread(j, 1, sizeof j - 1, f); fclose(f); j[n] = 0;
    const char *v;
    if ((v = jfind(j, "quit")) && strncmp(v, "true", 4) == 0) { logw("state: quit"); ExitProcess(0); }
    if ((v = jfind(j, "volume"))) g_volume = (float)atof(v);
    if ((v = jfind(j, "active"))) g_active = strncmp(v, "true", 4) == 0;
    g_nchain = 0;
    if ((v = jfind(j, "folders")) && (v = strchr(v, '['))) {
        const char *end = strchr(v, ']'); v++;
        while (end && v < end && g_nchain < MAX_CHAIN) {
            const char *q = strchr(v, '"'); if (!q || q > end) break;
            char s[64]; const char *after = jstr(q, s, sizeof s); if (!after) break;
            from_utf8(s, g_chain[g_nchain++], 64);
            v = after;
        }
    }
    char scene[64] = ""; if ((v = jfind(j, "scene"))) jstr(v, scene, sizeof scene);
    logw("state: scene=%s chain=%d volume=%.2f active=%d", scene, g_nchain, g_volume, g_active);
}

/* ---------- voices ---------- */
static void ramp(Voice *v, float target, int ms) {
    v->target = target; float d = target - v->vol; if (d < 0) d = -d;
    v->step = ms > 0 ? d * TICK_MS / ms : 1.0f; if (v->step <= 0) v->step = 1.0f;
}

static int free_slot(void) {
    for (int i = 0; i < MAX_VOICES; i++) if (!g_v[i].used) return i;
    int old = -1; for (int i = 0; i < MAX_VOICES; i++) if (i != g_cur && (old < 0 || g_v[i].left_at < g_v[old].left_at)) old = i;
    ma_sound_uninit(&g_v[old].snd); g_v[old].used = 0; return old;
}

static int start_track(const wchar_t *folder) {
    int n = list_tracks(folder, g_tracks, MAX_TRACKS); if (!n) return -1;
    int k = rand() % n;
    if (n > 1 && !_wcsicmp(g_tracks[k], g_last_file)) k = (k + 1) % n;    /* never the same track twice in a row */
    int s = free_slot(); Voice *v = &g_v[s];
    wchar_t path[MAX_PATH]; _snwprintf(path, MAX_PATH, L"%s\\%s\\%s", g_music, folder, g_tracks[k]);
    char u[MAX_PATH * 3]; to_utf8(path, u, sizeof u);
    if (ma_sound_init_from_file_w(&g_engine, path, MA_SOUND_FLAG_STREAM | MA_SOUND_FLAG_NO_SPATIALIZATION, NULL, NULL, &v->snd) != MA_SUCCESS) {
        logw("cannot open %s", u); return -1;
    }
    v->used = 1; v->paused = 0; v->vol = 0; wcscpy(v->folder, folder); wcscpy(v->file, g_tracks[k]); wcscpy(g_last_file, g_tracks[k]);
    v->gain = track_gain(g_tracks[k]); v->started = time(NULL); v->left_at = 0;
    ma_sound_set_volume(&v->snd, 0); ma_sound_start(&v->snd); ramp(v, 1.0f, FADE_IN_MS);
    logw("play %s", u); g_dirty = 1;
    return s;
}

static void leave_current(void) {
    if (g_cur < 0) return;
    ramp(&g_v[g_cur], 0, FADE_OUT_MS); g_v[g_cur].left_at = GetTickCount(); g_cur = -1; g_dirty = 1;
}

/* The folder that should sound now: the first of the chain with files; NULL — silence. */
static const wchar_t *wanted(void) {
    if (!g_active) return NULL;
    for (int i = 0; i < g_nchain; i++) if (folder_count(g_chain[i]) > 0) return g_chain[i];
    return NULL;
}

static void decide(void) {
    const wchar_t *w = wanted();
    if (g_cur >= 0 && w && !_wcsicmp(g_v[g_cur].folder, w)) return;       /* already there */
    if (g_cur < 0 && !w) return;
    leave_current();
    if (!w) { logw("silence"); return; }
    for (int i = 0; i < MAX_VOICES; i++) {                                  /* the grace period: resume, not restart */
        Voice *v = &g_v[i];
        if (v->used && !_wcsicmp(v->folder, w) && GetTickCount() - v->left_at < GRACE_MS) {
            if (v->paused) { ma_sound_start(&v->snd); v->paused = 0; }
            ramp(v, 1.0f, FADE_IN_MS); g_cur = i; v->left_at = 0; g_dirty = 1;
            char fu[128]; to_utf8(w, fu, sizeof fu); logw("resume %s", fu); return;
        }
    }
    g_cur = start_track(w);
}

static void tick(void) {
    for (int i = 0; i < MAX_VOICES; i++) {
        Voice *v = &g_v[i]; if (!v->used) continue;
        if (v->vol < v->target) { v->vol += v->step; if (v->vol > v->target) v->vol = v->target; }
        else if (v->vol > v->target) { v->vol -= v->step; if (v->vol < v->target) v->vol = v->target; }
        ma_sound_set_volume(&v->snd, v->vol * g_volume * v->gain);
        if (i != g_cur && v->vol <= 0 && !v->paused) { ma_sound_stop(&v->snd); v->paused = 1; }
        if (i != g_cur && v->paused && GetTickCount() - v->left_at > GRACE_MS) { ma_sound_uninit(&v->snd); v->used = 0; continue; }
        if (i == g_cur && ma_sound_at_end(&v->snd)) {                        /* the next track of the same folder */
            wchar_t f[64]; wcscpy(f, v->folder); ma_sound_uninit(&v->snd); v->used = 0; g_cur = -1;
            g_cur = start_track(f);
        }
    }
}

static void json_clean(char *s) { for (; *s; s++) if (*s == '"' || *s == '\\' || (unsigned char)*s < 0x20) *s = '_'; }

static void write_player_json(void) {
    if (!g_dirty) return; g_dirty = 0;
    wchar_t tmp[MAX_PATH], dst[MAX_PATH];
    _snwprintf(tmp, MAX_PATH, L"%s\\player.json.tmp", g_state_dir); _snwprintf(dst, MAX_PATH, L"%s\\player.json", g_state_dir);
    FILE *f = _wfopen(tmp, L"wb"); if (!f) return;
    char folder[128] = "", file[MAX_PATH * 3] = "", title[MAX_PATH * 3] = ""; long long started = 0;
    if (g_cur >= 0) {
        to_utf8(g_v[g_cur].folder, folder, sizeof folder); to_utf8(g_v[g_cur].file, file, sizeof file);
        strcpy(title, file); char *dot = strrchr(title, '.'); if (dot) *dot = 0; started = (long long)g_v[g_cur].started;
        json_clean(file); json_clean(title);
    }
    fprintf(f, "{\"pid\":%lu,\"playing\":%s,\"folder\":\"%s\",\"file\":\"%s\",\"title\":\"%s\",\"started\":%lld,\"inventory\":{",
            GetCurrentProcessId(), g_cur >= 0 ? "true" : "false", folder, file, title, started);
    for (int i = 0; i < g_nfolders; i++) { char n[128]; to_utf8(g_folders[i].name, n, sizeof n); json_clean(n); fprintf(f, "%s\"%s\":%d", i ? "," : "", n, g_folders[i].count); }
    fprintf(f, "}}");
    fclose(f);
    MoveFileExW(tmp, dst, MOVEFILE_REPLACE_EXISTING);
}

/* The game we serve: the nearest ancestor process that is the game (Lua starts us through cmd.exe), else any running game. */
static HANDLE find_game(void) {
    static DWORD pids[MAX_PROCS], pars[MAX_PROCS]; static wchar_t exes[MAX_PROCS][64]; int n = 0;
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0); if (snap == INVALID_HANDLE_VALUE) return NULL;
    PROCESSENTRY32W pe; pe.dwSize = sizeof pe;
    if (Process32FirstW(snap, &pe)) do {
        if (n < MAX_PROCS) { pids[n] = pe.th32ProcessID; pars[n] = pe.th32ParentProcessID; wcsncpy(exes[n], pe.szExeFile, 63); exes[n][63] = 0; n++; }
    } while (Process32NextW(snap, &pe));
    CloseHandle(snap);
    DWORD cur = GetCurrentProcessId(), game = 0;
    for (int depth = 0; depth < 8 && !game; depth++) {
        DWORD parent = 0; for (int i = 0; i < n; i++) if (pids[i] == cur) { parent = pars[i]; break; }
        if (!parent) break;
        for (int i = 0; i < n; i++) if (pids[i] == parent && !_wcsicmp(exes[i], GAME_EXE)) game = parent;
        cur = parent;
    }
    if (!game) for (int i = 0; i < n; i++) if (!_wcsicmp(exes[i], GAME_EXE)) { game = pids[i]; break; }
    if (!game) return NULL;
    logw("serving the game, pid %lu", game);
    return OpenProcess(SYNCHRONIZE, FALSE, game);
}

int WINAPI wWinMain(HINSTANCE hi, HINSTANCE hp, PWSTR cmd, int show) {
    (void)hi; (void)hp; (void)cmd; (void)show;
    int argc; wchar_t **argv = CommandLineToArgvW(GetCommandLineW(), &argc);
    if (argc >= 2) { wcsncpy(g_mod, argv[1], MAX_PATH - 1); size_t L = wcslen(g_mod); while (L && (g_mod[L - 1] == L'\\' || g_mod[L - 1] == L'/')) g_mod[--L] = 0; }
    else { GetModuleFileNameW(NULL, g_mod, MAX_PATH); *wcsrchr(g_mod, L'\\') = 0; *wcsrchr(g_mod, L'\\') = 0; } /* <mod>\player\x.exe */
    _snwprintf(g_music, MAX_PATH, L"%s\\music", g_mod); _snwprintf(g_state_dir, MAX_PATH, L"%s\\State", g_mod);
    CreateDirectoryW(g_state_dir, NULL);
    wchar_t lp[MAX_PATH]; _snwprintf(lp, MAX_PATH, L"%s\\player.log", g_state_dir);

    HANDLE mtx = CreateMutexW(NULL, TRUE, L"Local\\KrinikConanMusicPlayer");
    if (GetLastError() == ERROR_ALREADY_EXISTS) return 0;                   /* one player per session; the log belongs to the running one */
    g_log = _wfopen(lp, L"wb");
    /* argv[2] — the PID to serve instead of the game: the stand (tools/test_player.py) runs the player against a stand-in process. */
    HANDLE game = argc >= 3 ? OpenProcess(SYNCHRONIZE, FALSE, (DWORD)_wtoi(argv[2])) : find_game();
    if (argc >= 3) logw("serving pid %ls (stand)", argv[2]);
    if (!game) { logw("no game process - exit"); return 0; }
    if (ma_engine_init(NULL, &g_engine) != MA_SUCCESS) { logw("audio engine failed"); return 1; }
    srand((unsigned)GetTickCount());
    logw("KrinikConanMusic player started, miniaudio %s", MA_VERSION_STRING);

    FILETIME last = { 0 }; DWORD next_state = 0, next_scan = 0;
    for (;;) {
        if (WaitForSingleObject(game, 0) == WAIT_OBJECT_0) { logw("the game ended - exit"); break; }
        DWORD now = GetTickCount();
        if (now >= next_scan) { rescan(); next_scan = now + RESCAN_MS; }
        if (now >= next_state) {
            wchar_t p[MAX_PATH]; _snwprintf(p, MAX_PATH, L"%s\\state.json", g_state_dir);
            WIN32_FILE_ATTRIBUTE_DATA a;
            if (GetFileAttributesExW(p, GetFileExInfoStandard, &a) && CompareFileTime(&a.ftLastWriteTime, &last)) {
                last = a.ftLastWriteTime; read_state();
            }
            next_state = now + STATE_POLL_MS;
        }
        decide();
        tick();
        write_player_json();
        Sleep(TICK_MS);
    }
    ma_engine_uninit(&g_engine);
    CloseHandle(mtx);
    return 0;
}
