// KrinikConanUpdates — лента выпусков сборки и лаунчера, самообновление лаунчера и обновление сборки (KUMM plan 54; разведка
// KUMM researches/conan-launcher-updates/README.md). Слово владельца 2026-11-17 14:40: «Лаунчер, заметив новую версию сборки в релизах GH должен
// показывать плашку, что вышла новая версия. И должна появляться кнопка [Обновить сборку]» · «Когда будут выходить релизы по чисто лаунчеру, то будет
// кнопка [Обновить лаунчер] - чтобы это обновление не требовало скачки многих гигабайт всей сборки, а только легике файлы самого лаунчера».
// Лента — GitHub Releases публичного репозитория сборки (BuildInfo.FeedRepo): выпуски сборки — метки vX.Y.Z, выпуски лаунчера — launcher-vX.Y.Z
// (их публикуют с --latest=false, чтобы «Latest» на GitHub оставался за сборкой). Об игроке не уходит ничего: один анонимный GET публичного адреса.
// Каждый скачанный файл сверяется по SHA-256 с полем digest выпуска (GitHub пишет его у каждого файла выпуска).
// [NOT-TESTED]
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;

// Ход длинного дела для полосы прогресса окна (KUMM plans/57, критерий 7): фон пишет этап и числа, окно читает их по своему таймеру и само считает
// скорость и оставшееся время (Meter). Скачанное прежними запусками в скорость не входит: SessionStart — байты на начало этого запуска. [NOT-TESTED]
sealed class Job
{
    public enum Stage { Search, Download, Verify, Unpack, Remove, Install, Launcher }
    public volatile Stage Now;
    public volatile bool Update;            // обновление поставленной сборки (полоса «Обновление сборки до …»), а не первая установка
    public string Version = "";             // версия сборки или лаунчера, о которой идёт речь
    long done, total, sessionStart = -1;
    public long Done => Interlocked.Read(ref done);
    public long Total => Interlocked.Read(ref total);
    public long SessionStart => Interlocked.Read(ref sessionStart);
    public volatile int ModsDone, ModsTotal;
    public readonly Stopwatch Clock = Stopwatch.StartNew();
    public void Set(long d, long t)
    {
        Interlocked.Exchange(ref done, d);
        Interlocked.Exchange(ref total, t);
        Interlocked.CompareExchange(ref sessionStart, d, -1);
    }
    public void Enter(Stage s, long d = 0, long t = 0) { Now = s; Interlocked.Exchange(ref sessionStart, -1); Set(d, t); }
    public int Percent => Total > 0 ? (int)Math.Min(100, Done * 100 / Total) : 0;
}

// Скорость и оставшееся время, как у wget и tqdm (разведка §2.5): выборка счётчика по таймеру окна, скорость — экспонента с α 0,3 за секунду,
// оставшееся время пересчитывается не чаще раза в секунду; 5 с без новых байтов — «ожидание данных». [NOT-TESTED]
sealed class Meter
{
    const double ALPHA_PER_SECOND = 0.3, STALL_SECONDS = 5, ETA_REFRESH_SECONDS = 1;
    double ema = -1, lastT = -1, lastMove = -1, etaAt = -1;
    long lastBytes = -1;
    public double? Speed { get; private set; }
    public TimeSpan? Left { get; private set; }

    public void Reset() { ema = lastT = lastMove = etaAt = -1; lastBytes = -1; Speed = null; Left = null; }

    public void Sample(long bytes, long total, double t)
    {
        if (lastBytes < 0 || bytes < lastBytes) { lastBytes = bytes; lastT = lastMove = t; return; }
        double dt = t - lastT;
        if (dt <= 0) return;
        double rate = (bytes - lastBytes) / dt;
        if (bytes > lastBytes) lastMove = t;
        double a = 1 - Math.Pow(1 - ALPHA_PER_SECOND, dt);
        ema = ema < 0 ? rate : ema + a * (rate - ema);
        lastBytes = bytes; lastT = t;
        if (t - lastMove >= STALL_SECONDS || ema <= 0) { Speed = null; Left = null; etaAt = -1; return; }
        Speed = ema;
        if (etaAt < 0 || t - etaAt >= ETA_REFRESH_SECONDS) { Left = TimeSpan.FromSeconds(Math.Max(0, total - bytes) / ema); etaAt = t; }
    }
}

static class Feed
{
    public sealed class Asset { public string Name, Url, Sha256; public long Size; }
    // GameVersion / GameCl — для какой игры собрана сборка: строка-метка в тексте выпуска (комментарий HTML, на странице выпуска не видна)
    // «<!-- krinik-game: 3.1.1 CL-383549 -->» (разведка §3: список выпусков уже несёт текст, лишнего запроса нет). Выпуск без метки ни к одной игре
    // не подходит. [NOT-TESTED]
    public sealed class Release { public string Tag, Page, GameVersion; public int GameCl; public ReleaseNumber Number; public readonly List<Asset> Assets = new List<Asset>(); }
    public sealed class Answer
    {
        public Release Build, Launcher;
        public readonly List<Release> Builds = new List<Release>();
        // Новейшая сборка для этой игры: по номеру сборки Funcom из метки выпуска.
        public Release BuildFor(int cl)
        {
            Release best = null;
            if (cl > 0) foreach (var r in Builds) if (r.GameCl == cl && (best == null || r.Number > best.Number)) best = r;
            return best;
        }
    }
    static readonly Regex GAME_MARK = new Regex(@"krinik-game:\s*(?<v>\d+(?:\.\d+){1,3})\s+CL-(?<cl>\d+)", RegexOptions.CultureInvariant | RegexOptions.IgnoreCase);

    const string BUILD_PREFIX = "v", LAUNCHER_PREFIX = "launcher-v";
    // Лента — подсказка, а не условие запуска: окно открывается сразу, ответ ждём не дольше этого.
    const int FEED_TIMEOUT_MS = 5000;
    // Скачивание частей сборки: на медленной сети одна операция чтения может идти долго, но не минуту без единого байта.
    const int DOWNLOAD_TIMEOUT_MS = 60000;
    const int BUFFER = 1 << 20;
    // Адрес тестовой ленты (_config/launcher/test/feed.mjs); у игрока этой переменной нет.
    const string FEED_VARIABLE = "KRINIK_LAUNCHER_FEED";
    public const string AGENT = "KrinikConanLauncher";

    public static string Url
    {
        get
        {
            var v = Environment.GetEnvironmentVariable(FEED_VARIABLE);
            // 100 — предел GitHub на страницу: выпуски лаунчера занимают места в списке, и при 30 сборки для старых версий игры выпадали бы из ленты
            // (судья 2026-11-18, риск 10).
            return string.IsNullOrEmpty(v) ? "https://api.github.com/repos/" + BuildInfo.FeedRepo + "/releases?per_page=100" : v;
        }
    }

    // Без ответа ленты «Что нового» сборки ведёт сюда: GitHub сам перенаправляет на выпуск с меткой «Latest», а это всегда сборка.
    public static string LatestBuildPage => "https://github.com/" + BuildInfo.FeedRepo + "/releases/latest";

    static HttpWebRequest Request(string url, int timeout)
    {
        // GitHub отдаёт только TLS 1.2 и новее, а сборка без атрибута целевой платформы получает умолчания .NET 4.0 без TLS 1.2 (разведка §3).
        ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;
        var r = (HttpWebRequest)WebRequest.Create(url);
        r.UserAgent = AGENT + "/" + BuildInfo.LauncherVersion; // GitHub отклоняет запрос без User-Agent
        r.Timeout = r.ReadWriteTimeout = timeout;
        return r;
    }

    // Ответ сервера с кодом ошибки (408, 429, 5xx, 4xx) держит своё соединение, пока его не закрыть, а у .NET Framework их по умолчанию два на сервер:
    // после двух таких ответов следующее «Продолжить скачивание» ждало бы таймаута в 60 с (судья 2026-11-20, круг 3, находка 6). Закрывает его каждый
    // запрос ленты сам, у своего GetResponse: в круге 3 закрывали два внешних catch в BuildUpdate.Run, а проверка хвоста архива и самообновление
    // оставались открытыми (судья 2026-11-20, круг 4, находка 2). Повторное закрытие безвредно. [NOT-TESTED]
    public static void CloseResponse(Exception ex) { if (ex is WebException w) w.Response?.Close(); }

    static HttpWebResponse Respond(HttpWebRequest req)
    {
        try { return (HttpWebResponse)req.GetResponse(); }
        catch (WebException ex) { CloseResponse(ex); throw; }
    }

    // Последняя часть архива — правда ли последняя: части — побайтовая нарезка одного zip, и в конце ЦЕЛОГО архива лежит запись конца каталога
    // (сигнатура PK\5\6, у Zip64 — она же после локатора). Хвост 64 КБ по Range до скачивания 13 ГБ: нет записи — в выпуске не хватает частей
    // (план 54 «smaller» п. 3, кейс B5′). true — запись есть; false — нет; null — сервер не отдал кусок (не 206) — проверить нечем. [NOT-TESTED]
    const int EOCD_TAIL = 65557;   // 22 байта записи + до 65 535 байт комментария архива
    public static bool? HasZipEnd(string url, long size)
    {
        var req = Request(url, DOWNLOAD_TIMEOUT_MS);
        long from = Math.Max(0, size - EOCD_TAIL);
        req.AddRange(from);
        using (var resp = Respond(req))
        {
            if (resp.StatusCode != HttpStatusCode.PartialContent) return null;
            var ms = new MemoryStream();
            using (var s = resp.GetResponseStream()) s.CopyTo(ms);
            var b = ms.ToArray();
            for (int i = b.Length - 22; i >= 0; i--)
                if (b[i] == 0x50 && b[i + 1] == 0x4B && b[i + 2] == 0x05 && b[i + 3] == 0x06) return true;
            return false;
        }
    }

    public static Answer Read()
    {
        var req = Request(Url, FEED_TIMEOUT_MS);
        req.Accept = "application/vnd.github+json";
        using (var resp = Respond(req))
        using (var reader = new StreamReader(resp.GetResponseStream(), Encoding.UTF8))
            return Parse(reader.ReadToEnd());
    }

    // Из списка выпусков — новейшая сборка и новейший лаунчер; черновики и предварительные выпуски не считаются.
    public static Answer Parse(string json)
    {
        var answer = new Answer();
        if (!(new JavaScriptSerializer { MaxJsonLength = int.MaxValue }.DeserializeObject(json) is object[] list)) return answer;
        foreach (var item in list)
        {
            if (!(item is Dictionary<string, object> d) || Flag(d, "draft") || Flag(d, "prerelease")) continue;
            string tag = Str(d, "tag_name");
            bool launcher = tag.StartsWith(LAUNCHER_PREFIX, StringComparison.OrdinalIgnoreCase);
            string number = launcher ? tag.Substring(LAUNCHER_PREFIX.Length) : tag.StartsWith(BUILD_PREFIX, StringComparison.OrdinalIgnoreCase) ? tag.Substring(BUILD_PREFIX.Length) : null;
            var version = ParseVersion(number);
            if (version == null) continue;
            var release = new Release { Tag = tag, Page = Str(d, "html_url"), Number = version };
            var mark = GAME_MARK.Match(Str(d, "body"));
            if (mark.Success && int.TryParse(mark.Groups["cl"].Value, NumberStyles.None, CultureInfo.InvariantCulture, out int gameCl))
            {
                release.GameCl = gameCl;
                release.GameVersion = mark.Groups["v"].Value;
                Games.Learn(gameCl, release.GameVersion);
            }
            if (d.TryGetValue("assets", out var assets) && assets is object[] files)
                foreach (var f in files)
                    if (f is Dictionary<string, object> a)
                    {
                        string digest = Str(a, "digest");
                        release.Assets.Add(new Asset
                        {
                            Name = Str(a, "name"), Url = Str(a, "browser_download_url"), Size = a.TryGetValue("size", out var size) ? Convert.ToInt64(size, CultureInfo.InvariantCulture) : 0,
                            Sha256 = digest.StartsWith("sha256:", StringComparison.OrdinalIgnoreCase) ? digest.Substring(7).ToLowerInvariant() : ""
                        });
                    }
            if (launcher) { if (answer.Launcher == null || version > answer.Launcher.Number) answer.Launcher = release; }
            else
            {
                answer.Builds.Add(release);
                if (answer.Build == null || version > answer.Build.Number) answer.Build = release;
            }
        }
        return answer;
    }

    static bool Flag(Dictionary<string, object> d, string key) => d.TryGetValue(key, out var v) && v is bool b && b;
    static string Str(Dictionary<string, object> d, string key) => d.TryGetValue(key, out var v) && v is string s ? s : "";

    // Номер выпуска с порядком кандидатов RC1 < RC2 < … < окончательный (KrinikConanVersion.cs). До 2026-11-18 хвост «-rc1» отбрасывался — 0.9.1-RC1
    // и 0.9.1 были одним номером.
    public static ReleaseNumber ParseVersion(string text) => ReleaseNumber.Parse(text);

    public static bool Newer(ReleaseNumber feed, string current)
    {
        var mine = ParseVersion(current);
        return feed != null && mine != null && feed > mine;
    }

    // Скачивание с докачкой: часть файла уже есть — просим остаток (Range); сервер прислал файл целиком (200) — пишем заново.
    public static void Download(string url, string file, long size, Action<long> progress, Func<bool> cancelled)
    {
        long have = File.Exists(file) ? new FileInfo(file).Length : 0;
        if (have > size) { File.Delete(file); have = 0; }
        if (have == size && size > 0) { progress(have); return; }
        var req = Request(url, DOWNLOAD_TIMEOUT_MS);
        if (have > 0) req.AddRange(have);
        HttpWebResponse answer;
        try { answer = (HttpWebResponse)req.GetResponse(); }
        catch (WebException ex) when (have > 0 && ex.Response is HttpWebResponse bad && bad.StatusCode == HttpStatusCode.RequestedRangeNotSatisfiable)
        {
            // 416 — сервер не отдаёт остаток с этого места: повтор того же Range получил бы тот же 416, и «Продолжить скачивание» не выводило бы
            // игрока из ошибки (судья 2026-11-18, круг 2, находка 8). Скачанная часть удаляется, файл качается целиком. [NOT-TESTED]
            bad.Close();
            MetalWindow.Log($"{Path.GetFileName(file)}: сервер не отдал остаток с байта {have} (416), часть удалена и скачивается целиком");
            File.Delete(file);
            Download(url, file, size, progress, cancelled);
            return;
        }
        // Остальные ответы с ошибкой закрываются здесь, до выхода из Download (у ответа 416 выше статус ещё читается, поэтому он не идёт через Respond).
        catch (WebException ex) { CloseResponse(ex); throw; }
        using (var resp = answer)
        {
            bool partial = resp.StatusCode == HttpStatusCode.PartialContent;
            long done = partial ? have : 0;
            using (var src = resp.GetResponseStream())
            using (var dst = new FileStream(file, partial ? FileMode.Append : FileMode.Create, FileAccess.Write, FileShare.None, BUFFER))
            {
                var buf = new byte[BUFFER];
                int n;
                while (true)
                {
                    // Сбой ЧТЕНИЯ — это сеть (обрыв, сброс соединения): WebException, окно предложит «Продолжить скачивание»; сбой ЗАПИСИ (полный диск)
                    // остаётся IOException и называется игроку как ошибка (plans/57, критерий 8). [NOT-TESTED]
                    try { n = src.Read(buf, 0, buf.Length); }
                    catch (IOException ex) { throw new WebException("connection lost: " + ex.Message, ex); }   // в журнал; игрок видит v.net.stop
                    if (n <= 0) break;
                    if (cancelled()) throw new OperationCanceledException();
                    dst.Write(buf, 0, n);
                    done += n;
                    progress(done);
                }
            }
        }
        long got = new FileInfo(file).Length;
        if (got != size) throw new WebException($"downloaded {got} of {size} bytes: {Path.GetFileName(file)}");   // в журнал; игрок видит v.net.stop
    }

    public static string Sha256(string file, Action<long> progress, Func<bool> cancelled)
    {
        using (var sha = SHA256.Create())
        using (var fs = new FileStream(file, FileMode.Open, FileAccess.Read, FileShare.Read, BUFFER))
        {
            var buf = new byte[BUFFER];
            long done = 0;
            int n;
            while ((n = fs.Read(buf, 0, buf.Length)) > 0)
            {
                if (cancelled()) throw new OperationCanceledException();
                sha.TransformBlock(buf, 0, n, null, 0);
                done += n;
                progress?.Invoke(done);
            }
            sha.TransformFinalBlock(buf, 0, 0);
            var hex = new StringBuilder(64);
            foreach (var b in sha.Hash) hex.Append(b.ToString("x2"));
            return hex.ToString();
        }
    }

    public static string Size(long bytes) => Ui.Size(bytes);
}

// Версия сборки, рядом с которой лежит лаунчер: архив сборки кладёт pack\modpack.json в свой корень. После самообновления exe несёт версию сборки,
// с которой его собрали, а не ту, что лежит рядом, поэтому сначала читаем файл; нет файла — версия, вшитая при сборке.
// Так же — всё, что окно говорит о сборке и игре: версия игры, заметки Steam к ней, имя руководства и деинсталлятора (KUMM plan 54 blocker 3, epic 55 B3:
// лаунчер, обновившийся сам, показывал бы игру и руководство той сборки, с которой его скомпилировали). [NOT-TESTED]
static class Bundle
{
    static readonly Dictionary<string, Dictionary<string, object>> cache = new Dictionary<string, Dictionary<string, object>>(StringComparer.OrdinalIgnoreCase);

    // Окно читает манифест в своём потоке, обновление сборки — в потоке пула: словарь под замком (судья 2026-11-17).
    static Dictionary<string, object> Manifest(string here)
    {
        lock (cache) if (cache.TryGetValue(here, out var known)) return known;
        Dictionary<string, object> d = null;
        var file = Path.Combine(here, "pack", "modpack.json");
        try
        {
            if (File.Exists(file))
                d = new JavaScriptSerializer { MaxJsonLength = int.MaxValue }.DeserializeObject(File.ReadAllText(file, Encoding.UTF8)) as Dictionary<string, object>;
        }
        catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException || ex is ArgumentException || ex is InvalidOperationException)
        {
            MetalWindow.Log("pack\\modpack.json не прочитан: " + ex.Message);
        }
        lock (cache) cache[here] = d;
        return d;
    }

    // Папку переписала распаковка — прочитанное из неё раньше больше не правда.
    public static void Forget(string here) { lock (cache) cache.Remove(here); }

    static string Str(Dictionary<string, object> d, string key) => d != null && d.TryGetValue(key, out var v) && v is string s && s.Length > 0 ? s : null;
    static Dictionary<string, object> Obj(Dictionary<string, object> d, string key) => d != null && d.TryGetValue(key, out var v) ? v as Dictionary<string, object> : null;

    public static string PackVersion(string here) => Str(Manifest(here), "packVersion") ?? BuildInfo.PackVersion;
    // Версия ИМЕННО из папки, без вшитой запасной: распакованный архив проверяется по себе, а не по exe. null — в папке нет манифеста с версией.
    public static string PackVersionIn(string dir) => Str(Manifest(dir), "packVersion");
    public static string GameVersion(string here) => Str(Obj(Manifest(here), "launcher"), "gameVersion") ?? BuildInfo.GameVersion;
    // Так же без вшитой запасной: игра, для которой собрана сборка в этой папке (папка Krinik_* в игре, Games.InstalledVersion). null — манифест её не называет.
    public static string GameVersionIn(string dir) => Str(Obj(Manifest(dir), "launcher"), "gameVersion");
    public static string GameNotes(string here) => Str(Obj(Manifest(here), "launcher"), "gameNotes") ?? BuildInfo.GameNotes;
    // Руководство экспорт кладёт в корень архива под его собственным именем — берём имя файла из пути манифеста.
    public static string GuidePdf(string here) => Str(Manifest(here), "guide") is string g ? Path.GetFileName(g.Replace('/', '\\')) : BuildInfo.GuidePdf;
    public static string UninstallCmd(string here) => Str(Obj(Manifest(here), "uninstall"), "cmd") ?? BuildInfo.UninstallCmd;
}

// Консоли, которые запустил этот лаунчер (установщик, деинсталлятор): пока жива хоть одна, обновление не начинается — две установки в одну папку
// сломали бы журнал отката (KUMM plan 54 blocker 4, epic 55 B4). Обновление само держит именованный мьютекс: второй открытый лаунчер не начнёт своё. [NOT-TESTED]
static class Children
{
    static readonly List<Process> live = new List<Process>();
    public static void Track(Process p) { if (p == null) return; lock (live) live.Add(p); }
    public static bool AnyAlive
    {
        get
        {
            lock (live)
            {
                live.RemoveAll(p => { try { if (p.HasExited) { p.Dispose(); return true; } return false; } catch (InvalidOperationException) { return true; } });
                return live.Count > 0;
            }
        }
    }

    static Mutex updating;
    // Брать и отпускать — в одном потоке (у мьютекса Windows есть хозяин-поток): окно берёт его по нажатию и отпускает в ui().
    public static bool TakeUpdate()
    {
        if (updating == null) updating = new Mutex(false, @"Local\KrinikConanLauncherUpdate");
        try { return updating.WaitOne(0); }
        catch (AbandonedMutexException) { return true; }   // прежний владелец умер посреди обновления — мьютекс наш
    }
    public static void ReleaseUpdate() { try { updating?.ReleaseMutex(); } catch (ApplicationException) { } }
}

// «Обновить лаунчер»: скачать exe выпуска рядом с собой, сверить SHA-256, переименовать себя в .old (Windows не даёт перезаписать запущенный exe,
// но даёт его переименовать), поставить новый на своё место, запустить его и выйти. Новый убирает .old, только когда показал окно: до этого .old —
// единственный рабочий лаунчер (судья 2026-11-17: выпуск, падающий при старте, иначе стёр бы запасной и умер сам).
// С 2026-11-17 (epic 55 B2, разведка researches/conan-launcher-modern-practice §1.1 — Chromium «qualify, then activate»): прежний лаунчер не уходит, пока
// новый не докажет, что жив. Новый запускается с «--after-update <pid прежнего>», через 3 с после показа окна поднимает именованное событие; нет события
// за 30 с или новый вышел раньше — прежний гасит новый, возвращает себя на место и остаётся открытым. .old удаляется только на ВТОРОМ обычном запуске
// нового (коммит), а счётчик незавершённых запусков (<exe>.starting) возвращает прежний, если новый дважды не дожил до спокойного окна (антивирус убил
// его уже после сигнала — Firefox, startup crash counter). [NOT-TESTED]
static class SelfUpdate
{
    const string ASSET = "KrinikConanLauncher.exe", OLD = ".old", NEW = ".new", MARK = ".starting", BAD = ".bad", AFTER = "--after-update";
    const int CLEAN_TRIES = 20, CLEAN_PAUSE_MS = 500;
    const int READY_MS = 30000, READY_POLL_MS = 200, SETTLE_MS = 3000, MAX_UNFINISHED = 2;
    // Окно «живо» через столько мс после показа; стенд (live.mjs, кейс быстрого закрытия) растягивает его, чтобы закрытие окна заведомо пришло раньше
    // таймера. У игрока этой переменной нет.
    const string SETTLE_VARIABLE = "KRINIK_LAUNCHER_SETTLE_MS";
    static int afterPid;
    // Уже «жив»: таймер, закрытие окна игроком и начатое самообновление делают это один раз (1 — сделано или больше не нужно).
    static int settled;
    static bool shown;
    // Возврат на прежний лаунчер встал на полпути (Begin): этот запуск не коммитит обновление, .old и счётчик остаются, следующий запуск пробует возврат
    // снова. Судья B7, круг 2 (R7): иначе через 3 с этот же процесс удалял .old у лаунчера, которого счётчик дважды признал негодным. [NOT-TESTED]
    static bool keepOld;
    // Ошибка в окне (Application.ThreadException): окно «живым» больше не считается. Судья B7, круг 2 (R1): окно ошибки .NET крутит свой цикл сообщений,
    // и таймер «жив» срабатывал прямо за ним, прежний лаунчер уходил без отката. [NOT-TESTED]
    static volatile bool crashed;

    static string ReadyName(int pid) => @"Local\KrinikConanLauncherReady-" + pid;
    static void TryDelete(string f) { try { if (File.Exists(f)) File.Delete(f); } catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException) { } }
    static int SettleMs => int.TryParse(Environment.GetEnvironmentVariable(SETTLE_VARIABLE), out var ms) && ms > 0 && ms < READY_MS ? ms : SETTLE_MS;

    // Из Main до окна. true — этот процесс уступил место прежнему лаунчеру и должен выйти.
    public static bool Begin(string[] args)
    {
        for (int i = 0; i + 1 < args.Length; i++)
            if (args[i] == AFTER && int.TryParse(args[i + 1], out var p)) afterPid = p;
        string self = Application.ExecutablePath, old = self + OLD, mark = self + MARK;
        if (!File.Exists(old)) { TryDelete(mark); return false; }
        int count = 0;
        try { if (File.Exists(mark)) int.TryParse(File.ReadAllText(mark).Trim(), out count); } catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException) { }
        if (count >= MAX_UNFINISHED && afterPid == 0)
        {
            MetalWindow.Log($"новый лаунчер {count} раз не дожил до спокойного окна — возвращаю прежний");
            try
            {
                TryDelete(self + BAD);
                File.Move(self, self + BAD);
                File.Move(old, self);
                TryDelete(mark);
                Process.Start(new ProcessStartInfo(self) { WorkingDirectory = Path.GetDirectoryName(self), UseShellExecute = false });
                return true;
            }
            catch (Exception ex)
            {
                MetalWindow.Log("возврат прежнего лаунчера не удался: " + ex);
                // Возврат встал на полпути (прежний занят антивирусом, нет права записи): место exe не должно остаться пустым — ярлык игрока ведёт сюда.
                // Новый — обратно на своё место, .old не трогаем: он ещё единственный запасной (судья 2026-11-17, epic 55 B7 п. 3). [NOT-TESTED]
                if (!File.Exists(self) && File.Exists(self + BAD))
                    try { File.Move(self + BAD, self); MetalWindow.Log("новый лаунчер вернулся на своё место, прежний остался рядом как " + Path.GetFileName(old)); }
                    catch (Exception back) when (back is IOException || back is UnauthorizedAccessException) { MetalWindow.Log("и новый на место не вернулся: " + back.Message); }
                keepOld = true;
            }
        }
        try { File.WriteAllText(mark, (count + 1).ToString()); } catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException) { }
        return false;
    }

    // Из Shown окна: через 3 с — «жив»: ждущему прежнему лаунчеру — сигнал, на обычном запуске — коммит (прежний exe прочь).
    public static void Settled()
    {
        shown = true;
        var t = new System.Windows.Forms.Timer { Interval = SettleMs };
        t.Tick += (s, e) => { t.Stop(); t.Dispose(); Settle("окно живо"); };
        t.Start();
    }

    // Из FormClosed: показанное окно закрыли раньше таймера (крестик, Alt+F4, «Играть», «Снять задачу» диспетчера) — окно ответило на закрытие, это тоже
    // «жив». Судья 2026-11-17 (epic 55 B7 п. 1): «Играть» в первые 3 с считалось падением — прежний лаунчер откатывал обновление, а два быстрых закрытия при
    // лежащем .old возвращали прежний. Падение FormClosed не зовёт; окно ошибки .NET закрывает форму через Application.Exit — ApplicationExitCall сюда не
    // пускается. Стенд 2026-11-17 22:06: WM_CLOSE извне приходит как TaskManagerClosing, не UserClosing — первый вариант фильтра его отбросил. [NOT-TESTED]
    public static void Closed(CloseReason reason)
    {
        if (shown && reason != CloseReason.ApplicationExitCall) Settle("окно закрыто игроком");
    }

    // Из Application.ThreadException (KrinikConanLauncher.Main): ошибка в окне. Признак ставится ДО окна сообщения — его цикл сообщений иначе успел бы
    // отдать таймер «жив». Процесс выходит с кодом 1: ждущий прежний лаунчер видит выход без сигнала и откатывает обновление, на обычном запуске
    // остаётся счётчик незавершённых запусков. [NOT-TESTED]
    public static void Crash(Exception ex)
    {
        // Судья B7, круг 3 (R1): выход — только пока окно ещё не «живо» (первые 3 с, случай самообновления). Позже ошибка кнопки (нет программы для
        // PDF, антивирус не дал запустить .cmd) не закрывает лаунчер посреди установки или удаления: сообщение, и работа продолжается. [NOT-TESTED]
        if (Interlocked.CompareExchange(ref settled, 0, 0) == 1)
        {
            MetalWindow.Log("ошибка в окне лаунчера, окно продолжает работу: " + ex);
            try { MessageBox.Show(Application.OpenForms.Count > 0 ? Application.OpenForms[0] : null, Ui.F("box.error", ex.Message), Ui.T("caption"), MessageBoxButtons.OK, MessageBoxIcon.Warning); }
            catch (Exception) { }
            return;
        }
        crashed = true;
        MetalWindow.Log("ошибка в окне лаунчера: " + ex);
        try
        {
            MessageBox.Show(Application.OpenForms.Count > 0 ? Application.OpenForms[0] : null, Ui.F("box.error.exit", ex.Message), Ui.T("caption"), MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
        catch (Exception) { }
        Environment.Exit(1);
    }

    // Место exe пусто (оба переименования возврата не удались, Begin): к спокойному окну блокировка антивируса обычно снята — вернуть exe на место
    // ещё раз; не вышло — сказать игроку, какой файл переименовать. Судья B7, круг 2 (R5). [NOT-TESTED]
    static void RestoreSlot()
    {
        string self = Application.ExecutablePath;
        if (File.Exists(self)) return;
        foreach (var from in new[] { self + BAD, self + OLD })
        {
            if (!File.Exists(from)) continue;
            try { File.Move(from, self); MetalWindow.Log("место лаунчера снова занято: " + Path.GetFileName(from) + " → " + Path.GetFileName(self)); return; }
            catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException) { MetalWindow.Log("место лаунчера не занять из " + Path.GetFileName(from) + ": " + ex.Message); }
        }
        // Судья, круг 3 (C2): назвать файл, который действительно лежит рядом (.bad мог забрать антивирус). [NOT-TESTED]
        string spare = File.Exists(self + BAD) ? self + BAD : self + OLD;
        MessageBox.Show(Ui.F("box.slot", Path.GetDirectoryName(self), Path.GetFileName(spare), Path.GetFileName(self)), Ui.T("caption"), MessageBoxButtons.OK, MessageBoxIcon.Warning);
    }

    static void Settle(string why)
    {
        if (crashed) return;
        if (Interlocked.Exchange(ref settled, 1) == 1) return;
        if (afterPid == 0 && keepOld)
        {
            RestoreSlot();
            MetalWindow.Log(why + ", но возврат на прежний лаунчер встал на полпути: " + Path.GetFileName(Application.ExecutablePath + OLD) + " остаётся запасным, следующий запуск попробует возврат снова");
            return;
        }
        TryDelete(Application.ExecutablePath + MARK);
        if (afterPid == 0)
        {
            if (File.Exists(Application.ExecutablePath + OLD)) MetalWindow.Log(why + " — прежний лаунчер больше не нужен");
            CleanOld();
            return;
        }
        try
        {
            if (EventWaitHandle.TryOpenExisting(ReadyName(afterPid), out var h)) using (h) { h.Set(); MetalWindow.Log(why + " — сигнал прежнему лаунчеру " + afterPid); }
            else MetalWindow.Log(why + ", но прежний лаунчер " + afterPid + " уже не ждёт сигнала");
        }
        catch (Exception ex) { MetalWindow.Log("сигнал прежнему лаунчеру не ушёл: " + ex.Message); }
    }

    // Коммит самообновления: прежний exe (и брошенный .bad) — прочь.
    public static void CleanOld()
    {
        string self = Application.ExecutablePath, old = self + OLD;
        // Места exe нет (возврат встал на полпути) — .old сейчас единственный рабочий лаунчер: не трогать (судья 2026-11-17, epic 55 B7 п. 3).
        if (!File.Exists(self)) { MetalWindow.Log("на месте лаунчера пусто — " + Path.GetFileName(old) + " не удаляю"); return; }
        TryDelete(self + BAD);
        if (!File.Exists(old)) return;
        // Обычно прежний давно вышел — одна попытка сразу (окно может закрываться: потоки пула умрут вместе с процессом); не вышло — ещё несколько в фоне.
        try { File.Delete(old); MetalWindow.Log("удалён прежний лаунчер " + old); return; }
        catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException) { }
        ThreadPool.QueueUserWorkItem(_ =>
        {
            for (int i = 0; i < CLEAN_TRIES; i++)
            {
                Thread.Sleep(CLEAN_PAUSE_MS);
                try { File.Delete(old); MetalWindow.Log("удалён прежний лаунчер " + old); return; }
                catch (IOException) { }
                catch (UnauthorizedAccessException) { }
            }
            MetalWindow.Log("прежний лаунчер не удалился: " + old);
        });
    }

    // Работает в фоне. null — новый лаунчер запущен; иначе — текст для игрока, прежний лаунчер остаётся на месте. Ход — в job (полоса окна).
    public static string Run(Feed.Release release, Job job)
    {
        var asset = release.Assets.Find(a => string.Equals(a.Name, ASSET, StringComparison.OrdinalIgnoreCase));
        if (asset == null) return Ui.F("s.no.asset", release.Number, ASSET);
        if (asset.Sha256.Length == 0) return Ui.F("s.no.digest", ASSET);
        string self = Application.ExecutablePath, fresh = self + NEW, old = self + OLD;
        // Возврат на прежний лаунчер встал на полпути (keepOld): .old — единственный запасной, его нельзя стирать ради ещё одного нового лаунчера, который
        // ничем себя не доказал (судья, круг 3, R2). Сначала нужен перезапуск: следующий запуск попробует вернуть прежний. [NOT-TESTED]
        if (keepOld) return Ui.T("s.keep.old");
        job.Version = release.Number.ToString();
        job.Enter(Job.Stage.Launcher, 0, asset.Size);
        // Нажатое «Обновить лаунчер» — тоже «жив», и сделать это нужно ДО подмены exe: поздний таймер этого процесса иначе стёр бы счётчик запусков уже
        // нового лаунчера (имя файла то же), а ждущий прежний не получил бы сигнала. [NOT-TESTED]
        Settle("обновление лаунчера начато");
        try
        {
            // Старый .new от прежней попытки мог совпасть с выпуском по размеру — тогда докачка его пропустила бы и сумма не сошлась бы (судья).
            if (File.Exists(fresh)) File.Delete(fresh);
            Feed.Download(asset.Url, fresh, asset.Size, done => job.Set(done, asset.Size), () => false);
            if (Feed.Sha256(fresh, null, () => false) != asset.Sha256)
            {
                File.Delete(fresh);
                MetalWindow.Log("лаунчер " + release.Number + ": контрольная сумма не совпала, прежний оставлен");
                return Ui.T("s.digest.bad");
            }
            if (File.Exists(old)) File.Delete(old);
            File.Move(self, old);
            try { File.Move(fresh, self); }
            catch { File.Move(old, self); throw; }
            int me = Process.GetCurrentProcess().Id;
            using (var ready = new EventWaitHandle(false, EventResetMode.ManualReset, ReadyName(me)))
            {
                Process proc;
                try
                {
                    proc = Process.Start(new ProcessStartInfo(self, AFTER + " " + me) { WorkingDirectory = Path.GetDirectoryName(self), UseShellExecute = false });
                }
                catch (Exception start)
                {
                    // Новый не запустился (антивирус, запрет запуска, испорченный файл): прежний — обратно на место, новый — прочь.
                    MetalWindow.Log("новый лаунчер не запустился, откат: " + start);
                    return RollBack(self, old, fresh, Ui.F("s.not.started", release.Number, start.Message));
                }
                bool alive = false;
                for (int waited = 0; waited < READY_MS; waited += READY_POLL_MS)
                {
                    if (ready.WaitOne(READY_POLL_MS)) { alive = true; break; }
                    if (proc == null || proc.HasExited) break;
                }
                // Новый мог поднять сигнал и выйти (игрок нажал «Играть») между двумя проверками цикла: событие ручное, оно так и стоит (судья 2026-11-17).
                if (!alive) alive = ready.WaitOne(0);
                if (!alive)
                {
                    // Запустился, но окна не показал (упал в окне, убит, завис): гасим его и возвращаем себя — прежний остаётся открытым.
                    int? code = null;
                    try { if (proc != null && !proc.HasExited) { proc.Kill(); proc.WaitForExit(5000); } if (proc != null && proc.HasExited) code = proc.ExitCode; }
                    catch (Exception ex) when (ex is InvalidOperationException || ex is System.ComponentModel.Win32Exception) { }
                    MetalWindow.Log($"новый лаунчер {release.Number} не показал окно за {READY_MS / 1000} с (код {code?.ToString() ?? "—"}), откат");
                    return RollBack(self, old, fresh, Ui.F("s.no.window", release.Number));
                }
            }
            MetalWindow.Log("лаунчер обновлён до " + release.Number + ": " + self);
            return null;
        }
        catch (Exception ex)
        {
            MetalWindow.Log("самообновление: " + ex);
            // Сначала — вернуть прежний exe, если его место пусто (и при запрете записи тоже: судья, круг 2), потом — советы.
            if (!File.Exists(self) && File.Exists(old)) return RollBack(self, old, fresh, Ui.F("s.failed.back", ex.Message));
            if (ex is UnauthorizedAccessException) return Ui.F("s.no.write", Path.GetDirectoryName(self));
            return Ui.F("s.failed", ex.Message);
        }
    }

    static string RollBack(string self, string old, string fresh, string said)
    {
        try
        {
            if (File.Exists(self)) File.Move(self, fresh);
            File.Move(old, self);
            try { File.Delete(fresh); } catch (IOException) { } catch (UnauthorizedAccessException) { }
            return said;
        }
        catch (Exception ex)
        {
            MetalWindow.Log("откат не удался: " + ex);
            return Ui.F("s.rollback.failed", Path.GetFileName(old), Path.GetFileName(self));
        }
    }

    public static int Percent(long done, long total) => total > 0 ? (int)(done * 100 / total) : 0;
}

/// «Установить сборку» и «Обновить сборку» (KUMM plan 54, epic 55 B, plans/57 phases 3–4). Три источника сборки:
//   1) сборка уже распакована рядом с лаунчером (Local: install.ps1 и pack\modpack.json в его папке) — ставится как есть;
//   2) части архива выпуска (Krinik_Mod_Pack_X_Y_Z.zip.001 …) лежат рядом с лаунчером (Beside: игрок скачал их сам) — сверяются по SHA-256, не качаются
//      и не удаляются (это файлы игрока);
//   3) частей нет — скачиваются с GitHub в папку игры (<игра>\<архив>_parts) с докачкой, каждая сверяется по SHA-256.
// Части 2–3 распаковываются в папку игры (<игра>\<архив>: так новый лаунчер сам найдёт игру, как советует руководство), прежняя сборка снимается
// установщиком нового архива («-Upgrade») или своим деинсталлятором (архив старого вида), новая ставится своим install.ps1 — без окна консоли: строки
// установщика читает лаунчер и считает поставленные моды для полосы прогресса (plans/57, критерий 7; движок печатает по строке [ok]/[warn]/[FAIL] на мод).
sealed class BuildUpdate
{
    // Запас на диске сверх частей и распакованной сборки: игра и Windows тоже пишут на этот диск.
    const long RESERVE = 2L << 30;
    // Только наши архивы: имя с «Krinik_» и без точек — «.» или «..» вместо имени увели бы распаковку в саму папку игры или выше (судья 2026-11-17).
    static readonly Regex PART = new Regex(@"^(?<stem>Krinik_[A-Za-z0-9_]+)\.zip\.(?<n>\d{3})$", RegexOptions.CultureInvariant);
    static readonly Regex MOD_LINE = new Regex(@"^\s+\[(ok|warn|FAIL)\]\s+(?<rest>.+)$", RegexOptions.CultureInvariant);
    static readonly string[] GAME_PROCESSES = { "ConanSandbox", "ConanSandbox-Win64-Shipping" };
    const long FREE_UNKNOWN = -1;

    public Feed.Release Release;            // null — ставится распакованная рядом сборка (Local)
    public string GameDir, Stem, PartsDir, BundleDir, Uninstaller, Local;
    public bool Beside;
    public readonly List<Feed.Asset> Parts = new List<Feed.Asset>();
    public long Total, Have, Free, LocalSize;
    public string Version => Release != null ? Release.Number.ToString() : Bundle.PackVersionIn(Local) ?? "";
    public bool Installed => File.Exists(Uninstaller);
    // Чем кончилась остановка: «net» — оборвалась связь (окно предлагает «Продолжить скачивание»), «user» — игрок нажал «Отменить».
    public string Stop;
    // Дело прошло отказы до начала (игра запущена, окно установки открыто, запретная папка): только тогда ошибка пишет метку «error» в папку частей.
    // Отказ до начала скачивания папку частей не трогает (регрессия 2026-11-18 18:55: «every part is kept after the refusal — 90 of 89»). [NOT-TESTED]
    public bool Started;
    // Метка причины остановки в папке частей (net / user / error); её читает окно (Launcher.StopReason) и на следующем запуске.
    public const string STOP_MARK = ".krinik_stop";
    // Архив этого выпуска уже распакован целиком (прошлая попытка встала после распаковки): скачивание и распаковка пропускаются (судья 2026-11-17,
    // epic 55 B7 п. 2). «Целиком» держит метка pack\.krinik_unpacked, её пишет только Unpack и только последней.
    public bool Ready;
    // Сколько места ещё нужно: недокачанное + распаковка + копия модов в игру, когда прежней сборки нет (её снятие иначе освобождает примерно столько же)
    // + запас. Папка, оставшаяся от остановленной распаковки, перепишется целиком (судья B7, круг 2, R4). [NOT-TESTED]
    public long Need => Local != null ? (Installed ? 0 : LocalSize) + RESERVE
                                      : (Ready ? 0 : (Beside ? 0 : Total - Have) + Total) + (Installed ? 0 : Total) + RESERVE;
    public bool FreeKnown => Free != FREE_UNKNOWN;
    string Manifest => Path.Combine(BundleDir, "pack", "modpack.json");
    string Marker => Path.Combine(BundleDir, "pack", ".krinik_unpacked");
    string MarkerText => Release.Tag + "|" + Total;
    bool Unpacked
    {
        get
        {
            try
            {
                return File.Exists(Path.Combine(BundleDir, "install.ps1")) && File.Exists(Manifest) && File.Exists(Marker)
                    && File.ReadAllText(Marker).Trim() == MarkerText && Feed.ParseVersion(Bundle.PackVersionIn(BundleDir)) == Release.Number;
            }
            catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException) { return false; }
        }
    }

    // Сборка, распакованная рядом с лаунчером: в его папке install.ps1 и pack\modpack.json с версией. null — рядом такой нет.
    public static string LocalBundle(string here) =>
        File.Exists(Path.Combine(here, "install.ps1")) && Bundle.PackVersionIn(here) != null ? Path.GetFullPath(here).TrimEnd('\\') : null;

    public static BuildUpdate PrepareLocal(string gameDir, string here)
    {
        var u = new BuildUpdate { GameDir = gameDir, Local = LocalBundle(here), BundleDir = LocalBundle(here) };
        u.Uninstaller = Path.Combine(gameDir, Bundle.UninstallCmd(here));
        try { foreach (var f in new DirectoryInfo(u.Local).EnumerateFiles("*", SearchOption.AllDirectories)) u.LocalSize += f.Length; }
        catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException) { }
        u.ReadFree();
        return u;
    }

    // Проверки до нажатия. null — выпуск не годится, причина в why.
    public static BuildUpdate Prepare(Feed.Release release, string gameDir, string here, out string why)
    {
        why = null;
        if (gameDir == null) { why = Ui.T("u.no.game"); return null; }
        if (Games.Never(gameDir)) { why = Ui.T("u.never"); return null; }
        var u = new BuildUpdate { Release = release, GameDir = Path.GetFullPath(gameDir).TrimEnd('\\') };
        u.Uninstaller = Path.Combine(u.GameDir, Bundle.UninstallCmd(here));
        foreach (var a in release.Assets)
        {
            var m = PART.Match(a.Name);
            if (!m.Success) continue;
            if (u.Stem == null) u.Stem = m.Groups["stem"].Value;
            if (m.Groups["stem"].Value == u.Stem) u.Parts.Add(a);
        }
        u.Parts.Sort((x, y) => string.CompareOrdinal(x.Name, y.Name));
        for (int i = 0; i < u.Parts.Count; i++)
            if (u.Parts[i].Name != $"{u.Stem}.zip.{i + 1:000}" || u.Parts[i].Sha256.Length == 0 || !u.Parts[i].Url.StartsWith("http", StringComparison.OrdinalIgnoreCase))
            { u.Stem = null; break; }
        if (u.Stem == null || u.Parts.Count == 0) { why = Ui.F("u.no.archive", release.Number); return null; }
        u.BundleDir = Path.Combine(u.GameDir, u.Stem);
        if (string.Equals(Path.GetFullPath(u.BundleDir).TrimEnd('\\'), Path.GetFullPath(here).TrimEnd('\\'), StringComparison.OrdinalIgnoreCase))
        { why = Ui.F("u.over.self", release.Number); return null; }
        // Все части выпуска рядом с лаунчером, каждая своего размера, — их скачал игрок: качать нечего (критерий 4).
        u.Beside = u.Parts.TrueForAll(p => { var f = Path.Combine(here, p.Name); return File.Exists(f) && new FileInfo(f).Length == p.Size; });
        u.PartsDir = u.Beside ? Path.GetFullPath(here).TrimEnd('\\') : Path.Combine(u.GameDir, u.Stem + "_parts");
        foreach (var p in u.Parts)
        {
            u.Total += p.Size;
            var f = Path.Combine(u.PartsDir, p.Name);
            if (File.Exists(f)) u.Have += Math.Min(p.Size, new FileInfo(f).Length);
        }
        Bundle.Forget(u.BundleDir);
        u.Ready = u.Unpacked;
        u.ReadFree();
        return u;
    }

    void ReadFree()
    {
        // Сетевая папка игры (\\сервер\…) — DriveInfo её не знает: свободное место не проверяем и не называем.
        try { Free = new DriveInfo(Path.GetPathRoot(GameDir)).AvailableFreeSpace; }
        catch (Exception ex) when (ex is ArgumentException || ex is IOException || ex is UnauthorizedAccessException) { Free = FREE_UNKNOWN; MetalWindow.Log("свободное место не узнать: " + ex.Message); }
    }

    public static bool GameRunning()
    {
        foreach (var name in GAME_PROCESSES)
        {
            var ps = Process.GetProcessesByName(name);
            bool any = ps.Length > 0;
            foreach (var p in ps) p.Dispose();
            if (any) return true;
        }
        return false;
    }

    // Обрыв связи — не ошибка сборки: части сохраняются, окно предлагает «Продолжить скачивание». Переполненный диск — ошибка, о нём говорится.
    // Ответ сервера с кодом 4xx (403 — предел запросов, 404 — файла нет) — не обрыв: докачка его не исправит, и цикл «Продолжить скачивание» шёл бы
    // без конца (судья 2026-11-18, риск 11). 5xx — сбой на стороне сервера, его переживает повтор, как обрыв; так же 408 (сервер не дождался запроса)
    // и 429 (слишком много запросов): они проходят сами (судья 2026-11-18, круг 2, находка 8). 416 сюда не доходит: Feed.Download на него удаляет часть
    // и качает её целиком. [NOT-TESTED]
    static bool NetFailure(Exception ex)
    {
        if (!(ex is WebException w)) return false;
        if (w.Status != WebExceptionStatus.ProtocolError) return true;
        if (!(w.Response is HttpWebResponse r)) return false;
        int code = (int)r.StatusCode;
        return code >= 500 || code == 408 || code == 429;
    }

    // Работает в фоне. null — сборка стоит (путь нового лаунчера — NewLauncher); иначе — текст для игрока. stoppable(false) — дальше остановить
    // нельзя: снятие и установка сборки идут до конца (судья: «Остановить» после распаковки ничего не останавливал). press — подпись кнопки, которую
    // игрок нажмёт ещё раз.
    public string Run(Job job, Func<bool> cancelled, Action<bool> stoppable, string press)
    {
        job.Version = Version;
        try
        {
            // До первой скачанной части: игра или окно установки, открытое этим лаунчером, — обновление не начинается (epic 55 B4, кейсы B8′, B9′).
            // Запретная папка (never.txt) сборку не получает ни из ленты, ни из архива рядом (судья 2026-11-18, находка 1).
            if (Games.Never(GameDir)) return Ui.T("u.never");
            if (GameRunning()) return Ui.F("u.game.running", press);
            if (Children.AnyAlive) return Ui.F("u.console", press);
            Started = true;
            // Прежняя причина остановки стирается только здесь, после отказов: стёртая до них (в RunJob), она пропадала и на отказе — игрок остановил
            // скачивание, запустил игру, нажал «Продолжить скачивание», и экран «Вы остановили скачивание» сменялся «не закончил скачивание» (судья
            // 2026-11-18, круг 2, находка 5). [NOT-TESTED]
            if (PartsDir != null && !Beside)
                try { File.Delete(Path.Combine(PartsDir, STOP_MARK)); } catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException) { }
            if (Local != null) MetalWindow.Log($"ставлю сборку {Version}, распакованную рядом с лаунчером: {Local}");
            else if (Ready)
                MetalWindow.Log($"архив {Release.Number} уже распакован в {BundleDir} — скачивание и распаковка пропущены");
            else
            {
                if (!Beside)
                {
                    var last = Parts[Parts.Count - 1];
                    job.Enter(Job.Stage.Download, Have, Total);
                    bool? whole = null;
                    try { whole = Feed.HasZipEnd(last.Url, last.Size); }
                    catch (Exception ex) when (ex is WebException || ex is IOException) { MetalWindow.Log("хвост архива не прочитан: " + ex.Message); }
                    if (whole == false) return Ui.F("u.tail", Release.Number, last.Name);
                    MetalWindow.Log(whole == true ? "хвост архива проверен: последняя часть завершает архив" : "хвост архива не проверен: сервер не отдал кусок по Range");
                    Directory.CreateDirectory(PartsDir);
                }
                else
                {
                    job.Enter(Job.Stage.Verify, 0, Total);
                    MetalWindow.Log($"части выпуска {Release.Number} лежат рядом с лаунчером: {PartsDir} — скачивание пропущено");
                }
                var files = new List<string>();
                long before = 0;
                for (int i = 0; i < Parts.Count; i++)
                {
                    var p = Parts[i];
                    var file = Path.Combine(PartsDir, p.Name);
                    long at = before;
                    for (int attempt = 1; ; attempt++)
                    {
                        if (!Beside) Feed.Download(p.Url, file, p.Size, done => job.Set(at + done, Total), cancelled);
                        string sum = Feed.Sha256(file, Beside ? (Action<long>)(done => job.Set(at + done, Total)) : null, cancelled);
                        if (sum == p.Sha256) break;
                        if (Beside) return Ui.F("u.beside.bad", p.Name, Release.Number);
                        File.Delete(file);
                        MetalWindow.Log($"{p.Name}: контрольная сумма не совпала, попытка {attempt}");
                        if (attempt == 2) return Ui.F("u.twice", p.Name, press);
                    }
                    before += p.Size;
                    job.Set(before, Total);
                    files.Add(file);
                }
                Unpack(files, job, cancelled);
            }
            string install = Path.Combine(BundleDir, "install.ps1");
            if (!File.Exists(install)) return Ui.F("u.no.installer", BundleDir);
            // Архив обязан быть той версией, что в метке выпуска: иначе новый лаунчер снова увидит «новую» сборку и обновление пойдёт по кругу (судья, круг 2).
            string inside = Bundle.PackVersionIn(BundleDir) ?? "";
            if (Release != null && Feed.ParseVersion(inside) != Release.Number) return Ui.F("u.wrong.version", Release.Number, inside);
            // Последние отказы — ДО удаления частей: отказ «игра запущена» или «Отменить» после стёртых частей лгал бы «скачанное сохранено» (судья
            // 2026-11-17, epic 55 B7 п. 2). Синхронно и с последней проверкой: нажатое в этот миг «Отменить» не пропадает перед снятием сборки (судья, круг 2).
            if (GameRunning()) return Release != null ? Ui.F("u.game.running.ready", press, Release.Number) : Ui.F("u.game.running", press);
            stoppable(false);
            if (cancelled()) throw new OperationCanceledException();
            // Распакованная и узнанная сборка — скачанные части больше не нужны: удаляем до установки (пик места меньше на весь архив; план 54
            // «smaller» п. 2, epic 55 B5). Части рядом с лаунчером — файлы игрока, их лаунчер не трогает.
            if (Local == null && !Beside) DeleteParts();
            // Установщик архива с «-Upgrade» (движок KUMM с 2026-11-17, epic 55 B1) сам снимает прежнюю сборку и возвращает изменённые игроком настройки.
            // Архив старого вида — прежний путь: деинсталлятор, потом установщик.
            bool upgradeAware = File.ReadAllText(install).IndexOf("-Upgrade", StringComparison.Ordinal) >= 0;
            if (Installed && !upgradeAware)
            {
                job.Enter(Job.Stage.Remove);
                RunUninstaller();
                if (Installed) return Ui.F("u.not.removed", Path.GetFileName(Uninstaller), BundleDir);
            }
            job.Enter(Job.Stage.Install);
            // Код выхода — от install.ps1 напрямую: у install.cmd после «echo.» и «pause» он теряется (проба 2026-11-17 15:29).
            int code = RunInstaller(install, job);
            // Деинсталлятор — под именем НОВОЙ сборки (её манифест): у новой оно может быть другим (судья 2026-11-17).
            bool placed = File.Exists(Path.Combine(GameDir, Bundle.UninstallCmd(BundleDir)));
            if (code != 0 || !placed) return Ui.F("u.partial", Version, code, BundleDir);
            MetalWindow.Log($"сборка {Version} поставлена из {BundleDir}");
            return null;
        }
        catch (OperationCanceledException) { Stop = "user"; MetalWindow.Log("обновление остановлено игроком"); return Ui.T("u.stopped"); }
        catch (Exception ex) when (NetFailure(ex)) { Feed.CloseResponse(ex); Stop = "net"; MetalWindow.Log("связь оборвалась, скачанное сохранено: " + ex.Message); return Ui.T("v.net.stop"); }
        catch (Exception ex)
        {
            Feed.CloseResponse(ex);
            MetalWindow.Log("обновление сборки: " + ex);
            return Ui.F("u.failed", ex.Message);
        }
    }

    public string NewLauncher => Path.Combine(BundleDir, "KrinikConanLauncher.exe");

    // Уборка частей — не условие успеха (судья 2026-11-17). Все части выпуска по именам: после пропущенной загрузки (Ready) в папке могут лежать
    // части прошлой попытки.
    void DeleteParts()
    {
        if (!Directory.Exists(PartsDir)) return;
        foreach (var p in Parts)
        {
            var f = Path.Combine(PartsDir, p.Name);
            try { if (File.Exists(f)) File.Delete(f); } catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException) { MetalWindow.Log("часть не удалилась: " + ex.Message); }
        }
        try { Directory.Delete(PartsDir); } catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException) { MetalWindow.Log("папка частей осталась: " + ex.Message); }
    }

    // Части — один zip, разрезанный по байтам (make_volumes.sh): читаем их одним потоком, без склеенной копии на диске. Метка «распаковано целиком» —
    // pack\.krinik_unpacked: удаляется первой и пишется последней (судья B7, круг 2, R2). [NOT-TESTED]
    void Unpack(List<string> parts, Job job, Func<bool> cancelled)
    {
        string root = Path.GetFullPath(BundleDir).TrimEnd('\\') + "\\", manifest = Path.GetFullPath(Manifest), marker = Path.GetFullPath(Marker);
        if (File.Exists(marker)) File.Delete(marker);
        if (File.Exists(manifest)) File.Delete(manifest);
        Bundle.Forget(BundleDir);
        using (var all = new ConcatStream(parts))
        using (var zip = new ZipArchive(all, ZipArchiveMode.Read))
        {
            long total = 0, done = 0;
            foreach (var e in zip.Entries) total += e.Length;
            job.Enter(Job.Stage.Unpack, 0, total);
            var buf = new byte[1 << 20];
            ZipArchiveEntry last = null;
            Action<ZipArchiveEntry, string> write = (e, target) =>
            {
                Directory.CreateDirectory(Path.GetDirectoryName(target));
                using (var src = e.Open())
                using (var dst = new FileStream(target, FileMode.Create, FileAccess.Write, FileShare.None, buf.Length))
                {
                    int n;
                    while ((n = src.Read(buf, 0, buf.Length)) > 0)
                    {
                        if (cancelled()) throw new OperationCanceledException();
                        dst.Write(buf, 0, n);
                        done += n;
                        job.Set(done, total);
                    }
                }
            };
            foreach (var e in zip.Entries)
            {
                // Всё в архиве — внутри его папки сборки: путь наружу (..\) — испорченный архив, распаковка встаёт.
                string target = Path.GetFullPath(Path.Combine(GameDir, e.FullName.Replace('/', '\\')));
                if (!(target.TrimEnd('\\') + "\\").StartsWith(root, StringComparison.OrdinalIgnoreCase))
                    throw new InvalidDataException(Ui.F("u.bad.path", e.FullName));   // текст игроку — через u.failed, на языке окна (судья 2026-11-18)
                if (e.FullName.EndsWith("/")) { Directory.CreateDirectory(target); continue; }
                if (string.Equals(target, manifest, StringComparison.OrdinalIgnoreCase)) { last = e; continue; }
                write(e, target);
            }
            if (last != null) write(last, manifest);
        }
        Directory.CreateDirectory(Path.GetDirectoryName(marker));
        File.WriteAllText(marker, MarkerText);
        Bundle.Forget(BundleDir);
    }

    // Деинсталлятор — свой .cmd в корне игры; stdin — nul, чтобы «pause» в его конце не ждал клавишу. Успех — его исчезновение.
    void RunUninstaller()
    {
        var psi = new ProcessStartInfo("cmd.exe", "/c \"" + Quote(Uninstaller) + " < nul\"") { UseShellExecute = false, WorkingDirectory = GameDir, CreateNoWindow = true };
        MetalWindow.Log("запускаю " + psi.FileName + " " + psi.Arguments);
        using (var p = Process.Start(psi)) { p.WaitForExit(); MetalWindow.Log("код выхода " + p.ExitCode); }
    }

    // Моды архива — для «Скопировано модов N из M»: включённые записи pack\modpack.json; поставленный мод — строка движка [ok]/[warn]/[FAIL]
    // с его именем (Deploy-ModPack.ps1 Invoke-DeployTarget). Каждое имя считается один раз: строки проверки после раскатки с теми же именами счёт
    // не двигают. [NOT-TESTED]
    static List<string> ModNames(string bundleDir)
    {
        var names = new List<string>();
        try
        {
            var d = new System.Web.Script.Serialization.JavaScriptSerializer { MaxJsonLength = int.MaxValue }
                .DeserializeObject(File.ReadAllText(Path.Combine(bundleDir, "pack", "modpack.json"), Encoding.UTF8)) as Dictionary<string, object>;
            if (d != null && d.TryGetValue("mods", out var mods) && mods is object[] list)
                foreach (var m in list)
                    if (m is Dictionary<string, object> mod && mod.TryGetValue("name", out var n) && n is string name && !(mod.TryGetValue("enabled", out var en) && en is bool b && !b))
                        names.Add(name);
        }
        catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException || ex is ArgumentException || ex is InvalidOperationException) { MetalWindow.Log("моды архива не прочитаны: " + ex.Message); }
        names.Sort((a, b) => b.Length.CompareTo(a.Length));   // длинное имя раньше: «ModB» не съест строку «ModB2»
        return names;
    }

    int RunInstaller(string ps1, Job job)
    {
        var names = ModNames(BundleDir);
        var seen = new HashSet<string>(StringComparer.Ordinal);
        job.ModsTotal = names.Count;
        job.ModsDone = 0;
        // Без хвостового «\»: у игры в корне диска "D:\" стало бы D:" (кавычка экранирована) — судья, круг 2.
        var psi = new ProcessStartInfo("powershell.exe", "-NoProfile -ExecutionPolicy Bypass -File " + Quote(ps1) + " -GameDir " + Quote(GameDir.TrimEnd('\\')))
        {
            UseShellExecute = false, WorkingDirectory = BundleDir, CreateNoWindow = true,
            RedirectStandardOutput = true, RedirectStandardError = true, RedirectStandardInput = true
        };
        MetalWindow.Log("запускаю " + psi.FileName + " " + psi.Arguments);
        using (var p = Process.Start(psi))
        {
            p.StandardInput.Close();   // install.ps1 спрашивает папку игры только без -GameDir; закрытый ввод не даст ему ждать вечно
            DataReceivedEventHandler line = (s, e) =>
            {
                if (e.Data == null) return;
                MetalWindow.Log("установщик: " + e.Data);
                var m = MOD_LINE.Match(e.Data);
                if (!m.Success) return;
                string rest = m.Groups["rest"].Value;
                foreach (var n in names)
                    if (rest.StartsWith(n + " ", StringComparison.Ordinal) || rest.StartsWith(n + ":", StringComparison.Ordinal) || rest == n)
                    {
                        lock (seen) if (seen.Add(n)) job.ModsDone = seen.Count;
                        break;
                    }
            };
            p.OutputDataReceived += line;
            p.ErrorDataReceived += line;
            p.BeginOutputReadLine();
            p.BeginErrorReadLine();
            p.WaitForExit();
            MetalWindow.Log("код выхода " + p.ExitCode + ", модов в строках установщика " + job.ModsDone + " из " + job.ModsTotal);
            return p.ExitCode;
        }
    }

    static string Quote(string s) => "\"" + s + "\"";
}

// Части архива одним потоком только для чтения: ZipArchive нужен поток с переходом по месту (каталог zip лежит в конце последней части).
sealed class ConcatStream : Stream
{
    readonly FileStream[] files;
    readonly long[] starts;
    readonly long length;
    long position;

    public ConcatStream(IList<string> paths)
    {
        files = new FileStream[paths.Count];
        starts = new long[paths.Count];
        try
        {
            for (int i = 0; i < paths.Count; i++)
            {
                files[i] = new FileStream(paths[i], FileMode.Open, FileAccess.Read, FileShare.Read, 1 << 16);
                starts[i] = length;
                length += files[i].Length;
            }
        }
        catch { Dispose(true); throw; }
    }

    public override bool CanRead => true;
    public override bool CanSeek => true;
    public override bool CanWrite => false;
    public override long Length => length;
    public override long Position { get => position; set => position = value; }

    public override int Read(byte[] buffer, int offset, int count)
    {
        if (position >= length || count <= 0) return 0;
        int i = files.Length - 1;
        while (i > 0 && starts[i] > position) i--;
        var f = files[i];
        long inside = position - starts[i];
        f.Position = inside;
        int n = f.Read(buffer, offset, (int)Math.Min(count, f.Length - inside));
        position += n;
        return n;
    }

    public override long Seek(long offset, SeekOrigin origin)
    {
        position = origin == SeekOrigin.Begin ? offset : origin == SeekOrigin.Current ? position + offset : length + offset;
        if (position < 0) throw new IOException(Ui.T("u.bad.archive"));
        return position;
    }

    public override void Flush() { }
    public override void SetLength(long value) => throw new NotSupportedException();
    public override void Write(byte[] buffer, int offset, int count) => throw new NotSupportedException();

    protected override void Dispose(bool disposing)
    {
        if (disposing) foreach (var f in files) f?.Dispose();
        base.Dispose(disposing);
    }
}
