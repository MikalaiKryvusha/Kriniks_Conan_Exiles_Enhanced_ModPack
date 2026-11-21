// KrinikConanGames — где на компьютере лежит Conan Exiles, какой он версии и что в нём стоит (KUMM plans/57, phase 2; разведка
// KUMM researches/conan-launcher-self-sufficient/README.md §2–3). Слово владельца 2026-11-18 08:18–08:22 и 10:04 (verbatim — KUMM PROJECT_HISTORY.md,
// entry 2026-11-18 08:11): лаунчер сам находит игру на дисках, копии часто ставят в C:\Games или D:\Games — их смотрим сразу после Steam.
// Порядок поиска: папка лаунчера и три уровня выше (лаунчер распакован в игру — это её игра, дальше не ищем) → папка, выбранная игроком раньше
// (State) → Steam (реестр, оба libraryfolders.vdf, appmanifest_440900.acf) → на каждом несъёмном диске X:\Games и стандартные папки → обход диска
// на 4 уровня в пределах 15 с. Копия игры — папка, где лежат ConanSandbox.exe и ConanSandbox\Binaries\Win64\ConanSandbox-Win64-Shipping.exe.
// Версия — по номеру сборки Funcom (CL) в ProductVersion исполняемого файла игры: «++exiles+release-CL-383549» (1,1 мс, проверено 2026-11-18 10:10).
// Стенд подменяет диски (KRINIK_LAUNCHER_SEARCH_ROOTS) и папку Steam (KRINIK_LAUNCHER_STEAM): ни один прогон не читает игры владельца, если его об этом
// не просят. У игрока этих переменных нет. [NOT-TESTED]
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using Microsoft.Win32;

// Своя папка лаунчера: %LOCALAPPDATA%\KrinikConanLauncher (её не чистит «Очистка диска»; судья epic 55 B8, круг 3, R4). Стенд подменяет её
// переменной KRINIK_LAUNCHER_STATE_DIR и не трогает папки владельца (EXP-0560). Ошибка папки — лаунчер работает без памяти, а не падает.
static class State
{
    public static string Dir()
    {
        var dir = Environment.GetEnvironmentVariable("KRINIK_LAUNCHER_STATE_DIR");
        if (string.IsNullOrEmpty(dir)) dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "KrinikConanLauncher");
        Directory.CreateDirectory(dir);
        return dir;
    }

    public static string Read(string name)
    {
        try { var f = Path.Combine(Dir(), name); return File.Exists(f) ? File.ReadAllText(f, Encoding.UTF8).Trim() : null; }
        catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException || ex is NotSupportedException || ex is ArgumentException) { return null; }
    }

    public static void Write(string name, string text)
    {
        try { File.WriteAllText(Path.Combine(Dir(), name), text, new UTF8Encoding(false)); }
        catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException || ex is NotSupportedException || ex is ArgumentException)
        { MetalWindow.Log("папка состояния лаунчера: " + name + " не записан: " + ex.Message); }
    }
}

enum CopyKind { Clean, Krinik, OtherMods }

sealed class GameCopy
{
    public string Dir;              // полный путь без «\» в конце
    public int Cl;                  // номер сборки Funcom; 0 — не прочитан
    public CopyKind Kind;
    public string BuildVersion;     // стоит сборка Krinik — её версия, если её папка лежит в игре; иначе null
    // Игра, ДЛЯ КОТОРОЙ собрана поставленная сборка: launcher.gameVersion манифеста её папки Krinik_* в игре; null — манифест его не называет. Шапка
    // берёт номер игры отсюда, а не у найденной копии (судья 2026-11-18, круг 2, находка 3: Funcom обновил игру до 3.2.0 — шапка складывалась в
    // «0.9.1 для 3.2.0», хотя 0.9.1 собрана для 3.1.1). [NOT-TESTED]
    public string BuildGame;
    public string Version => Games.VersionOf(Cl);
    public string Exe => Path.Combine(Dir, Games.GAME_EXE);
}

static class Games
{
    public const string GAME_EXE = "ConanSandbox.exe";
    const string SHIPPING = @"ConanSandbox\Binaries\Win64\ConanSandbox-Win64-Shipping.exe";
    const string STEAM_APP = "440900";
    // Лаунчер распакован в игру или в папку сборки внутри неё (руководство: «распакуйте архив в папку игры»): столько уровней вверх.
    const int UP_LEVELS = 3;
    const int WALK_DEPTH = 4, WALK_BUDGET_MS = 15000;
    const int STEAM_FULLY_INSTALLED = 4;
    const string CHOSEN_FILE = "game.txt";
    const string ROOTS_VARIABLE = "KRINIK_LAUNCHER_SEARCH_ROOTS", STEAM_VARIABLE = "KRINIK_LAUNCHER_STEAM";

    // Номер сборки Funcom → версия игры. Источник — строка builtFor манифеста сборки (ConanExiles/modpack.json, 2026-11-18): 3.1.1 = CL-383549 и прежние.
    // Новые версии лаунчер узнаёт из выпусков на GitHub (метка krinik-game в тексте выпуска, Feed.Parse) — Learn.
    static readonly Dictionary<int, string> known = new Dictionary<int, string>
    {
        { 383549, "3.1.1" }, { 383024, "3.1.0" }, { 379176, "3.0.1" }, { 378132, "2.2.3" }, { 373655, "2.1.1" }
    };

    public static void Learn(int cl, string version) { if (cl > 0 && !string.IsNullOrEmpty(version)) lock (known) known[cl] = version; }
    public static string VersionOf(int cl) { lock (known) return cl > 0 && known.TryGetValue(cl, out var v) ? v : null; }

    // Ход поиска для полосы окна: фон пишет, окно читает по таймеру.
    public sealed class Progress { public volatile int DrivesDone, DrivesTotal; public volatile string Drive = ""; }

    static readonly Regex CL = new Regex(@"-CL-(\d+)", RegexOptions.CultureInvariant);
    static readonly byte[] CL_MARK = Encoding.Unicode.GetBytes("++exiles+release-CL-");

    // Номер сборки из ProductVersion исполняемого файла игры; нет «-CL-» — поиск той же строки UTF-16 в самом файле (около секунды на 200 МБ, разведка §2.3).
    public static int ReadCl(string dir)
    {
        foreach (var rel in new[] { SHIPPING, GAME_EXE })
        {
            var exe = Path.Combine(dir, rel);
            if (!File.Exists(exe)) continue;
            try
            {
                var m = CL.Match(FileVersionInfo.GetVersionInfo(exe).ProductVersion ?? "");
                if (m.Success && int.TryParse(m.Groups[1].Value, NumberStyles.None, CultureInfo.InvariantCulture, out int cl)) return cl;
            }
            catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException || ex is ArgumentException) { }
        }
        var shipping = Path.Combine(dir, SHIPPING);
        if (!File.Exists(shipping)) return 0;
        // Поиск внутри файла — около секунды на 200 МБ, а Describe зовётся на каждом Refresh окна: номер запоминается по пути, размеру и времени записи
        // файла (судья 2026-11-18, риск 9: окно замирало на каждой перерисовке). [NOT-TESTED]
        string key;
        try { var fi = new FileInfo(shipping); key = shipping.ToLowerInvariant() + "|" + fi.Length + "|" + fi.LastWriteTimeUtc.Ticks; }
        catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException) { return ScanCl(shipping); }
        lock (scanned) if (scanned.TryGetValue(key, out int known)) return known;
        int found = ScanCl(shipping);
        lock (scanned) scanned[key] = found;
        return found;
    }

    static readonly Dictionary<string, int> scanned = new Dictionary<string, int>();
    // Папки игры, которые Steam ещё докачивает (StateFlags без «установлено полностью»): поиск их не предлагает.
    static readonly HashSet<string> incomplete = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

    static int ScanCl(string file)
    {
        try
        {
            using (var fs = new FileStream(file, FileMode.Open, FileAccess.Read, FileShare.ReadWrite, 1 << 16))
            {
                var buf = new byte[(1 << 20) + CL_MARK.Length + 32];
                int keep = 0, n;
                while ((n = fs.Read(buf, keep, buf.Length - keep)) > 0)
                {
                    int len = keep + n, cut = -1;
                    for (int i = 0; i + CL_MARK.Length + 2 <= len; i++)
                    {
                        if (buf[i] != CL_MARK[0]) continue;
                        int k = 1;
                        while (k < CL_MARK.Length && buf[i + k] == CL_MARK[k]) k++;
                        if (k < CL_MARK.Length) continue;
                        int cl = 0, j = i + CL_MARK.Length, digits = 0;
                        for (; j + 1 < len && buf[j] >= (byte)'0' && buf[j] <= (byte)'9' && buf[j + 1] == 0 && digits < 9; j += 2, digits++) cl = cl * 10 + (buf[j] - '0');
                        // Цифры дошли до конца куска — номер может продолжаться в следующем: метка с цифрами переносится целиком (судья 2026-11-18, риск 8:
                        // метка в последних байтах куска давала 383 вместо 383549). [NOT-TESTED]
                        if (j + 1 >= len) { cut = i; break; }
                        if (digits > 0) return cl;
                    }
                    // хвост длиной в метку и цифры — в начало буфера: метка на стыке двух кусков не теряется
                    keep = cut >= 0 ? len - cut : Math.Min(len, CL_MARK.Length + 30);
                    Buffer.BlockCopy(buf, len - keep, buf, 0, keep);
                }
            }
        }
        catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException) { MetalWindow.Log("версия игры не прочитана: " + ex.Message); }
        return 0;
    }

    static bool IsGame(string dir) => File.Exists(Path.Combine(dir, GAME_EXE)) && File.Exists(Path.Combine(dir, SHIPPING));

    static string Norm(string dir)
    {
        try { return Path.GetFullPath(dir).TrimEnd('\\'); }
        catch (Exception ex) when (ex is ArgumentException || ex is NotSupportedException || ex is PathTooLongException || ex is System.Security.SecurityException) { return null; }
    }

    // Что стоит в копии: деинсталлятор сборки Krinik в корне вместе с журналом раскатки (_kumm_backup\journal.txt) — оба кладёт только раскатка сборки;
    // чужие моды — pak в ConanSandbox\Mods, непустой modlist.txt или UE4SS рядом с игрой.
    // Один деинсталлятор без журнала — остаток законченного удаления: себя он стирает последней строкой, после «pause», и игрок, закрывший окно
    // крестиком, оставлял его в чистой игре, а лаунчер показывал «сборка стоит» (KUMM bugs/115, 2026-11-21). Удачное удаление уносит папку копий с
    // журналом, неудачное оставляет оба.
    public static GameCopy Describe(string dir, string uninstallCmd)
    {
        var c = new GameCopy { Dir = dir, Cl = ReadCl(dir) };
        try
        {
            if (File.Exists(Path.Combine(dir, uninstallCmd)) && File.Exists(JournalOf(dir)))
            {
                c.Kind = CopyKind.Krinik;
                (c.BuildVersion, c.BuildGame) = InstalledVersion(dir);
                return c;
            }
            string mods = Path.Combine(dir, "ConanSandbox", "Mods"), list = Path.Combine(mods, "modlist.txt");
            bool other = Directory.Exists(mods) && Directory.EnumerateFiles(mods, "*.pak").GetEnumerator().MoveNext();
            if (!other && File.Exists(list)) other = File.ReadAllText(list).Trim().Length > 0;
            if (!other) other = Directory.Exists(Path.Combine(dir, "ConanSandbox", "Binaries", "Win64", "ue4ss"));
            c.Kind = other ? CopyKind.OtherMods : CopyKind.Clean;
        }
        catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException) { MetalWindow.Log("копия игры не разобрана: " + dir + ": " + ex.Message); }
        return c;
    }

    // Номер поставленной сборки. Его пишет установщик (KUMM Deploy-ModPack.ps1) в _kumm_backup\pack_version.txt, удаление сборки уносит его вместе с папкой
    // копий. Распакованная папка сборки рядом с игрой ещё не значит, что она поставлена: обновление, распакованное и остановленное (игра запущена, игрок
    // отменил), выдавало себя за поставленное, и плашка обновления пропадала (судья 2026-11-18, находка 2). Установка до записи номера (0.9.0) — по папкам
    // Krinik_*: распакованные самим игроком (без метки лаунчера pack\.krinik_unpacked) важнее распакованных лаунчером, из них — новейшая. [NOT-TESTED]
    // Вторая половина — игра, для которой собрана эта сборка: launcher.gameVersion манифеста папки Krinik_* с тем же номером (у записи — папка этого
    // номера, у установки без записи — выбранная папка).
    static (string version, string gameVersion) InstalledVersion(string dir)
    {
        try
        {
            ReleaseNumber recorded = null;
            string record = Path.Combine(dir, BACKUP_DIR, PACK_VERSION_FILE);
            if (File.Exists(record)) recorded = Feed.ParseVersion(File.ReadAllText(record).Trim());
            ReleaseNumber byHand = null, byLauncher = null;
            string recordedGame = null, handGame = null, launcherGame = null;
            foreach (var sub in Directory.EnumerateDirectories(dir, "Krinik_*"))
            {
                // Папка сборки по списку файлов, ещё не собранная (<корень>.staging), — не поставленная сборка (судья 2026-11-21, круг 2, R4). [NOT-TESTED]
                if (sub.EndsWith(Delta.STAGING, StringComparison.OrdinalIgnoreCase)) continue;
                var v = Feed.ParseVersion(Bundle.PackVersionIn(sub));
                if (v == null) continue;
                string gv = Bundle.GameVersionIn(sub);
                if (recorded != null) { if (v == recorded && recordedGame == null) recordedGame = gv; continue; }
                bool launcherMade = File.Exists(Path.Combine(sub, "pack", ".krinik_unpacked"));
                if (launcherMade) { if (byLauncher == null || v > byLauncher) { byLauncher = v; launcherGame = gv; } }
                else if (byHand == null || v > byHand) { byHand = v; handGame = gv; }
            }
            if (recorded != null) return (recorded.ToString(), recordedGame);
            return byHand != null ? (byHand.ToString(), handGame) : (byLauncher?.ToString(), launcherGame);
        }
        catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException) { return (null, null); }
    }

    const string BACKUP_DIR = "_kumm_backup", PACK_VERSION_FILE = "pack_version.txt", JOURNAL_FILE = "journal.txt";

    // Журнал раскатки сборки (KUMM Deploy-ModPack.ps1, Get-JournalPath): пока он есть, удаление сборки ещё не прошло.
    public static string JournalOf(string dir) => Path.Combine(dir, BACKUP_DIR, JOURNAL_FILE);

    // Игра, в которую распакован лаунчер (или сборка с ним): игра — она, искать дальше не нужно. Для такой папки хватает ConanSandbox.exe.
    public static string Around(string here)
    {
        var dir = new DirectoryInfo(here);
        for (int i = 0; dir != null && i <= UP_LEVELS; i++, dir = dir.Parent)
            if (File.Exists(Path.Combine(dir.FullName, GAME_EXE))) return dir.FullName.TrimEnd('\\');
        return null;
    }

    // Папка, которую игрок выбрал раньше (в списке копий или «Указать папку игры»), — пока в ней игра и пока она не запретная.
    public static string Chosen()
    {
        var d = State.Read(CHOSEN_FILE);
        return !string.IsNullOrEmpty(d) && File.Exists(Path.Combine(d, GAME_EXE)) && !Never(d) ? d : null;
    }

    // Запретные папки: never.txt в папке состояния лаунчера, одна папка на строку; копия игры в такой папке или под ней не предлагается и не получает
    // сборку. Так держат нетронутой эталонную копию игры (у автора сборки — скачанная чистая версия, KUMM HOUSE_RULES правило 25; судья 2026-11-18,
    // находка 1: обход диска предлагал её, и выбор ставил в неё сборку). Файла нет — запретных папок нет. [NOT-TESTED]
    // Строка — путь в кавычках или без: «Копировать как путь» Проводника даёт «"D:\Instals"», и кавычка роняла Path.GetFullPath — строка молча
    // пропадала, и эталонная копия снова предлагалась (судья 2026-11-18, круг 2, находка 4). Годится только полный путь (X:\… или \\сервер\…):
    // «Instals» или «\Instals» читались бы от рабочей папки лаунчера. Пропущенную строку лаунчер пишет в журнал один раз за запуск. [NOT-TESTED]
    public static bool Never(string dir)
    {
        var text = State.Read(NEVER_FILE);
        if (string.IsNullOrEmpty(text) || dir == null) return false;
        string d = Norm(dir);
        if (d == null) return false;
        foreach (var line in text.Split('\n'))
        {
            string raw = line.Trim().Trim('"').Trim();
            if (raw.Length == 0) continue;
            string n = FullPath(raw) ? Norm(raw) : null;
            if (n == null)
            {
                lock (neverSkipped) if (neverSkipped.Add(raw)) MetalWindow.Log("never.txt: строка пропущена, это не полный путь к папке: " + raw);
                continue;
            }
            if (string.Equals(d, n, StringComparison.OrdinalIgnoreCase) || d.StartsWith(n + "\\", StringComparison.OrdinalIgnoreCase)) return true;
        }
        return false;
    }

    static bool FullPath(string p) =>
        p.Length >= 3 && char.IsLetter(p[0]) && p[1] == ':' && (p[2] == '\\' || p[2] == '/') || p.StartsWith(@"\\", StringComparison.Ordinal);

    static readonly HashSet<string> neverSkipped = new HashSet<string>(StringComparer.Ordinal);
    const string NEVER_FILE = "never.txt";

    public static void Choose(string dir) { State.Write(CHOSEN_FILE, dir); MetalWindow.Log("игра выбрана: " + dir); }

    // Весь поиск — в фоне. Каждая найденная копия — один раз (полный путь без учёта регистра).
    public static List<string> Search(Progress p, Func<bool> cancelled)
    {
        var found = new List<string>();
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        Action<string> add = d =>
        {
            d = d == null ? null : Norm(d);
            if (d == null || !seen.Add(d) || !IsGame(d)) return;
            lock (incomplete) if (incomplete.Contains(d)) return;
            if (Never(d)) { MetalWindow.Log("копия игры в запретной папке (never.txt), не предлагается: " + d); return; }
            found.Add(d);
            MetalWindow.Log("найдена игра: " + d);
        };
        // Число дисков известно до Steam: полоса с первого кадра пишет «0 из N», а не «0 из 0» (кадр реального поиска 2026-11-18 15:56).
        var roots = Roots();
        p.DrivesTotal = roots.Count;
        p.Drive = "Steam";
        foreach (var lib in SteamLibraries()) foreach (var d in SteamGames(lib)) add(d);
        var clock = Stopwatch.StartNew();
        foreach (var root in roots)
        {
            if (cancelled()) break;
            p.Drive = root.TrimEnd('\\', ':');
            foreach (var d in Children(Path.Combine(root, "Games"))) { add(d); foreach (var dd in Children(d)) add(dd); }
            foreach (var pr in new[] { @"SteamLibrary\steamapps\common", @"Steam\steamapps\common", @"Program Files (x86)\Steam\steamapps\common",
                                       @"Program Files\Steam\steamapps\common", "Program Files (x86)", "Program Files", "Epic Games" })
                foreach (var d in Children(Path.Combine(root, pr))) add(d);
            Walk(root, 0, add, clock, cancelled);
            p.DrivesDone++;
        }
        MetalWindow.Log($"поиск игры: {found.Count} копий за {clock.ElapsedMilliseconds} мс, дисков {roots.Count}");
        return found;
    }

    static readonly HashSet<string> SKIP = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
    { "Windows", "Windows.old", "$Recycle.Bin", "System Volume Information", "Recovery", "PerfLogs", "ProgramData", "WindowsApps", "AppData", ".git", "node_modules", "ConanSandbox" };

    // Обход диска: не глубже WALK_DEPTH, без системных папок и без точек повторного разбора (петли junction, заглушки OneDrive), в общем бюджете времени;
    // ошибка одной папки — дальше. В найденную игру не спускаемся.
    static void Walk(string dir, int depth, Action<string> add, Stopwatch clock, Func<bool> cancelled)
    {
        if (depth >= WALK_DEPTH || clock.ElapsedMilliseconds > WALK_BUDGET_MS || cancelled()) return;
        foreach (var d in Children(dir))
        {
            if (File.Exists(Path.Combine(d, GAME_EXE))) { add(d); continue; }
            Walk(d, depth + 1, add, clock, cancelled);
        }
    }

    static IEnumerable<string> Children(string dir)
    {
        var list = new List<string>();
        try
        {
            if (!Directory.Exists(dir)) return list;
            foreach (var d in new DirectoryInfo(dir).EnumerateDirectories())
            {
                if (SKIP.Contains(d.Name) || (d.Attributes & FileAttributes.ReparsePoint) != 0 || (d.Attributes & FileAttributes.System) != 0 && d.Parent?.Parent == null) continue;
                list.Add(d.FullName);
            }
        }
        catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException || ex is PathTooLongException || ex is System.Security.SecurityException) { }
        return list;
    }

    // Диски компьютера: несъёмные и готовые (DriveType.Fixed); стенд даёт свои папки вместо дисков.
    static List<string> Roots()
    {
        var list = new List<string>();
        var forced = Environment.GetEnvironmentVariable(ROOTS_VARIABLE);
        if (forced != null)
        {
            foreach (var r in forced.Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries)) if (Directory.Exists(r)) list.Add(Norm(r) + "\\");
            return list;
        }
        foreach (var d in DriveInfo.GetDrives())
            try { if (d.DriveType == DriveType.Fixed && d.IsReady) list.Add(d.RootDirectory.FullName); }
            catch (IOException) { }
        return list;
    }

    // --- Steam

    static List<string> SteamLibraries()
    {
        var libs = new List<string>();
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var steam in SteamRoots())
        {
            if (seen.Add(steam)) libs.Add(steam);
            foreach (var vdf in new[] { Path.Combine(steam, "config", "libraryfolders.vdf"), Path.Combine(steam, "steamapps", "libraryfolders.vdf") })
                foreach (var lib in LibraryPaths(vdf))
                {
                    var n = Norm(lib);
                    if (n != null && seen.Add(n)) libs.Add(n);
                }
        }
        return libs;
    }

    static List<string> SteamRoots()
    {
        var roots = new List<string>();
        var forced = Environment.GetEnvironmentVariable(STEAM_VARIABLE);
        if (forced != null)
        {
            if (Directory.Exists(forced)) roots.Add(Norm(forced));
            return roots;
        }
        Action<string> add = p => { var n = p == null ? null : Norm(p.Replace('/', '\\')); if (n != null && Directory.Exists(n) && !roots.Contains(n)) roots.Add(n); };
        try { using (var k = Registry.CurrentUser.OpenSubKey(@"Software\Valve\Steam")) add(k?.GetValue("SteamPath") as string); } catch (Exception) { }
        foreach (var view in new[] { RegistryView.Registry32, RegistryView.Registry64 })
            try
            {
                using (var b = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, view))
                using (var k = b.OpenSubKey(@"SOFTWARE\Valve\Steam")) add(k?.GetValue("InstallPath") as string);
            }
            catch (Exception) { }
        return roots;
    }

    // libraryfolders.vdf двух видов: новый — «"libraryfolders" { "0" { "path" "…" } }», старый — «"LibraryFolders" { "1" "D:\\SteamLibrary" }».
    static IEnumerable<string> LibraryPaths(string vdf)
    {
        var list = new List<string>();
        var root = Vdf.Read(vdf);
        if (root == null) return list;
        Dictionary<string, object> lf = null;
        foreach (var kv in root) if (string.Equals(kv.Key, "libraryfolders", StringComparison.OrdinalIgnoreCase)) lf = kv.Value as Dictionary<string, object>;
        if (lf == null) return list;
        foreach (var kv in lf)
        {
            if (kv.Value is string s && kv.Key.Length > 0 && char.IsDigit(kv.Key[0])) list.Add(s);
            else if (kv.Value is Dictionary<string, object> d && d.TryGetValue("path", out var p) && p is string ps) list.Add(ps);
        }
        return list;
    }

    // Игра в библиотеке: appmanifest_440900.acf с «установлено полностью» (StateFlags & 4) и её installdir; без манифеста — папки common\* с игрой.
    // LastOwner манифеста (SteamID) не читается и не пишется в журнал (правило владельца об анонимности).
    static IEnumerable<string> SteamGames(string lib)
    {
        var list = new List<string>();
        string common = Path.Combine(lib, "steamapps", "common");
        var acf = Vdf.Read(Path.Combine(lib, "steamapps", "appmanifest_" + STEAM_APP + ".acf"));
        Dictionary<string, object> app = null;
        if (acf != null) foreach (var kv in acf) if (string.Equals(kv.Key, "AppState", StringComparison.OrdinalIgnoreCase)) app = kv.Value as Dictionary<string, object>;
        if (app != null && app.TryGetValue("installdir", out var dir) && dir is string ds)
        {
            int flags = app.TryGetValue("StateFlags", out var f) && f is string fs && int.TryParse(fs, out int fi) ? fi : 0;
            if ((flags & STEAM_FULLY_INSTALLED) != 0) list.Add(Path.Combine(common, ds));
            else
            {
                // Steam докачивает игру: её папка не предлагается ни здесь, ни обходом диска (судья 2026-11-18, риск 7 — папка common\* и обход диска
                // добавляли её всё равно). [NOT-TESTED]
                lock (incomplete) incomplete.Add(Norm(Path.Combine(common, ds)));
                MetalWindow.Log($"Steam: игра в {lib} установлена не полностью (StateFlags {flags})");
            }
        }
        foreach (var d in Children(common)) list.Add(d);
        return list;
    }
}

// Текст KeyValues Valve: строки в кавычках или без, { } вложение, «//» комментарии, «\\» и «\"» внутри строк. Ключи без учёта регистра. Сломанный файл —
// null («Steam нет»), не исключение.
static class Vdf
{
    public static Dictionary<string, object> Read(string file)
    {
        try { return File.Exists(file) ? Parse(File.ReadAllText(file, Encoding.UTF8)) : null; }
        catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException || ex is FormatException) { MetalWindow.Log("файл Steam не прочитан: " + file + ": " + ex.Message); return null; }
    }

    public static Dictionary<string, object> Parse(string text)
    {
        int i = 0;
        var root = Block(text, ref i, false);
        return root;
    }

    static Dictionary<string, object> Block(string t, ref int i, bool nested)
    {
        var d = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
        while (true)
        {
            string key = Token(t, ref i, out bool brace);
            // Тексты разбора — служебные, для журнала (сломанный файл — «Steam нет»): по-английски, игроку они не показываются.
            if (key == null) { if (nested) throw new FormatException("no closing brace"); return d; }
            if (brace) { if (key == "}") { if (!nested) throw new FormatException("extra closing brace"); return d; } throw new FormatException("a brace instead of a key"); }
            string value = Token(t, ref i, out bool vbrace);
            if (value == null) throw new FormatException("a key without a value: " + key);
            if (vbrace) { if (value != "{") throw new FormatException("a brace instead of a value"); d[key] = Block(t, ref i, true); }
            else d[key] = value;
        }
    }

    static string Token(string t, ref int i, out bool brace)
    {
        brace = false;
        while (i < t.Length)
        {
            char c = t[i];
            if (char.IsWhiteSpace(c)) { i++; continue; }
            if (c == '/' && i + 1 < t.Length && t[i + 1] == '/') { while (i < t.Length && t[i] != '\n') i++; continue; }
            if (c == '{' || c == '}') { brace = true; i++; return c.ToString(); }
            var sb = new StringBuilder();
            if (c == '"')
            {
                i++;
                while (i < t.Length && t[i] != '"')
                {
                    if (t[i] == '\\' && i + 1 < t.Length) { i++; sb.Append(t[i] == 'n' ? '\n' : t[i] == 't' ? '\t' : t[i]); i++; continue; }
                    sb.Append(t[i++]);
                }
                if (i >= t.Length) throw new FormatException("a string without a closing quote");
                i++;
                return sb.ToString();
            }
            while (i < t.Length && !char.IsWhiteSpace(t[i]) && t[i] != '{' && t[i] != '}' && t[i] != '"') sb.Append(t[i++]);
            return sb.ToString();
        }
        return null;
    }
}
