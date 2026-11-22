/// KrinikConanLauncher (до 2026-10-31 17:34 KrinikLauncher) — лаунчер сборки Krinik (KUMM idea 22). Слово владельца 2026-10-31 11:11: «пусть в поставке игры будет наш exe
// лаунчер на будущее, и пусть ОТЗЫВ в нем открывает красиво сообщение инструкцию для игрока, как и куда писать КРинику отзыв, и какую папку
// приложить» · 11:20 «сделаешь раздел со ссылками автора».
// Вид окна — слово владельца 2026-10-31 17:42: «я сказал в лаунчере на фоне наш волпейпер» · «без виндовского бордера и кнопок» ·
// «кастомная кнопка закрытия и сворачивания в стиле металла конана» · «бордер кастомный в стиле металла конана» ·
// 17:51 «В ЛАУНЧЕРЕ чистый волпейпер!» · «БЕЗ ЗАПЕЧЁННЫХ ЛОГОТИПОВ! ЛОГОТИПЫ САМИ СТАВИМ!». Раскладка — утверждённый макет 11 (_config/launcher/mockups/,
// KUMM idea 22, «APPROVED 18:53»); с 2026-11-18 столбик и состояния — макеты KUIPS design/mockups.html (KUMM plans/57, приняты владельцем 15:03):
// золотая главная кнопка наверху столбика на постоянном месте, под ней — состояние списком или полоса прогресса, внизу «Руководство», «Отзыв»,
// «Удалить сборку» (`[OWNER]` 2026-11-18 08:41).
// С 2026-11-18 (plans/57) лаунчер самостоятельный: сам находит игру на дисках (KrinikConanGames.cs), сам видит выпуск сборки для её версии на GitHub,
// качает его с докачкой и ставит, каждый долгий процесс — полосой прогресса; окно показывает только то, что есть на диске и в ленте: состояние
// выводится из фактов (Launcher.Refresh), стендовой переменной, которая подменяла состояние окна, больше нет — критерий 9.
// Слова окна — таблица KrinikConanText.cs (русский и английский, переключатель слева от кнопок окна; `[OWNER]` 2026-11-18 15:08).
// Числа раскладки — логические пиксели макета (окно 960×540 при 100 %), Windows умножает их на свой масштаб (HOUSE_RULES правило 17);
// картинки — из исходников под 4K при 300 %, окно их только уменьшает; res/ делает make-res.py.
// Ссылки автора и версии не вписаны руками: их кладёт _config/release/build-docs.py из author_links.txt и modpack.json (BuildInfo.g.cs).
// Собирается компилятором C# из Visual Studio 2022 против .NET Framework 4.x — он встроен в Windows 10/11, игроку ставить нечего.
// [NOT-TESTED] — новый столбик, поиск игры и установка с полосой прогресса (2026-11-18); прежние отметки о проверке — у своих частей ниже.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;

static class KrinikConanLauncher
{
    // Окно уважает масштаб Windows (у владельца ТВ на 300 %) и не растягивается картинкой — HOUSE_RULES §1 правило 17.
    [DllImport("user32.dll")] static extern bool SetProcessDpiAwarenessContext(IntPtr value);
    static readonly IntPtr PER_MONITOR_AWARE_V2 = new IntPtr(-4);

    // Надписи таблички «Отзыв»: светлый пергамент и золото металла, тёмная обводка у каждой буквы.
    internal static readonly Color Ink = Metal.Html("#f7ecd6"), Muted = Metal.Html("#e4d6bd"), Gold = Metal.Html("#f2c977");

    internal const string REPORT_CMD = "collect_report.cmd";
    // Проверка без браузера: KRINIK_LAUNCHER_DRY=1 — ссылки и запуски пишутся в журнал, а не открываются. У игрока этой переменной нет.
    internal static readonly bool Dry = Environment.GetEnvironmentVariable("KRINIK_LAUNCHER_DRY") == "1";

    [STAThread]
    static void Main(string[] args)
    {
        // После самообновления: «--after-update <pid>» и счётчик незавершённых запусков (KrinikConanUpdates, SelfUpdate.Begin) — до окна.
        if (SelfUpdate.Begin(args)) return;
        for (int i = 0; i + 1 < args.Length; i++) if (args[i] == OLD_BUNDLE_ARG) oldBundle = args[i + 1];
        try { SetProcessDpiAwarenessContext(PER_MONITOR_AWARE_V2); } catch (EntryPointNotFoundException) { /* Windows старше 10 1703 */ }
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        // Ошибка в окне — своё сообщение и выход с кодом 1, без окна ошибки .NET с «Продолжить» (судья B7, круг 2, R1). [NOT-TESTED]
        Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);
        Application.ThreadException += (s, e) => SelfUpdate.Crash(e.Exception);
        Ui.Init();
        Frames.HideBoxes();
        Application.Run(new Launcher().Form);
    }

    internal static string Here => AppDomain.CurrentDomain.BaseDirectory;

    internal static Icon AppIcon()
    {
        try
        {
            using (var s = Assembly.GetExecutingAssembly().GetManifestResourceStream("res.app.ico"))
                if (s != null) return new Icon(s);
        }
        catch (ArgumentException) { }
        return Icon.ExtractAssociatedIcon(Application.ExecutablePath);
    }

    internal static OutlinedLabel Text(string text, float pt, FontStyle style, Color color, string family = "Segoe UI") => new OutlinedLabel
    {
        Text = text, AutoSize = true, ForeColor = color, Font = new Font(family, pt, style),
        Margin = new Padding(0, 0, 0, 2) // предел ширины ставит FitWidth при раскладке окна
    };

    internal static MetalButton BigButton(string text) => new MetalButton
    {
        Text = text, AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink, Font = new Font("Georgia", 14f, FontStyle.Bold),
        Padding = new Padding(18, 9, 18, 9), Margin = new Padding(0, 0, 0, 12), Cursor = Metal.Hand
    };

    // Кнопка столбика: размер и шрифт в пикселях экрана ставит окно (MetalWindow.Relayout) по макету — 270×44, Georgia bold 18.7 px.
    internal static MetalButton ColumnButton() => new MetalButton { Cursor = Metal.Hand };

    // Ссылку открывает браузер Windows; при проверке (Dry) — только строка журнала. Только адреса http(s): ссылка ленты идёт в ShellExecute.
    internal static void Open(string url)
    {
        if (!(url.StartsWith("https://", StringComparison.OrdinalIgnoreCase) || url.StartsWith("http://", StringComparison.OrdinalIgnoreCase))) url = Feed.LatestBuildPage;
        MetalWindow.Log((Dry ? "открыл бы " : "открываю ") + url);
        if (Dry) return;
        try { Process.Start(new ProcessStartInfo(url) { UseShellExecute = true }); }
        catch (Exception ex)
        {
            MetalWindow.Log("ссылка не открылась: " + ex.Message);
            MessageBox.Show(Ui.F("box.link", url), Ui.T("box.notes"), MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
    }

    // Обновление начинается одно на машине (второй открытый лаунчер получит отказ) и не поверх открытого окна установки (epic 55 B4, кейсы L9, B9′).
    // true — мьютекс взят: отпустить после конца обновления (Children.ReleaseUpdate). [NOT-TESTED]
    internal static bool UpdateAllowed(Form form, string title)
    {
        if (Children.AnyAlive) { MessageBox.Show(form, Ui.T("box.console"), title, MessageBoxButtons.OK, MessageBoxIcon.Information); return false; }
        if (!Children.TakeUpdate()) { MessageBox.Show(form, Ui.T("box.other"), title, MessageBoxButtons.OK, MessageBoxIcon.Information); return false; }
        return true;
    }

    // Лента — подсказка: любая её ошибка (сеть, ответ не того вида) значит «не ответила», а не падение лаунчера.
    internal static Feed.Answer ReadFeed()
    {
        try { return Feed.Read(); }
        catch (Exception ex) { MetalWindow.Log("лента не ответила: " + ex.Message); return null; }
    }

    // false — программа не запустилась: тогда лаунчер не закрывается и говорит, где лежит новый.
    internal static bool Start(string exe, string args = "")
    {
        MetalWindow.Log((Dry ? "запустил бы " : "запускаю ") + exe + (args.Length > 0 ? " " + args : ""));
        if (Dry) return true;
        try { Process.Start(new ProcessStartInfo(exe, args) { WorkingDirectory = Path.GetDirectoryName(exe), UseShellExecute = false }); return true; }
        catch (Exception ex) { MetalWindow.Log("программа не запустилась: " + exe + ": " + ex.Message); return false; }
    }

    // Папка прежней сборки после «Обновить сборку» — отработанная поставка (≈ 13 ГБ; правило четырёх вещей владельца 2026-11-17, epic 55 B5): новый
    // лаунчер, запущенный прежним с «--old-bundle <папка>», предлагает её удалить — только папку с именем архива сборки (Krinik_…) и без признаков игры
    // внутри; кнопка по умолчанию — «Нет» (судья 2026-11-17, epic 55 B7 п. 4). [TESTED: 2026-11-18 · stand L9 · KUMM testcases/reports/2026-11-18_conan-launcher-b7-verification.md]
    internal const string OLD_BUNDLE_ARG = "--old-bundle";
    static readonly System.Text.RegularExpressions.Regex BUNDLE_NAME = new System.Text.RegularExpressions.Regex(@"^Krinik_[A-Za-z0-9_]+$");
    static readonly string[] GAME_SIGNS = { "Saved", "Content", "Binaries", "ConanSandbox" };
    static string oldBundle;

    internal static void OfferOldBundle(Form form)
    {
        if (string.IsNullOrEmpty(oldBundle)) return;
        string dir, here = Path.GetFullPath(Here).TrimEnd('\\');
        try { dir = Path.GetFullPath(oldBundle).TrimEnd('\\'); } catch (Exception ex) when (ex is ArgumentException || ex is NotSupportedException || ex is PathTooLongException) { return; }
        if (string.Equals(dir, here, StringComparison.OrdinalIgnoreCase) || here.StartsWith(dir + "\\", StringComparison.OrdinalIgnoreCase)) return;
        if (!BUNDLE_NAME.IsMatch(Path.GetFileName(dir)) || Array.Exists(GAME_SIGNS, n => Directory.Exists(Path.Combine(dir, n))))
        { MetalWindow.Log("папку прежней сборки не предлагаю удалить — не похожа на распакованный архив: " + dir); return; }
        if (!File.Exists(Path.Combine(dir, "pack", "modpack.json")) || File.Exists(Path.Combine(dir, Games.GAME_EXE))) return;
        // Сборка, собранная по списку файлов, делит с прежней неизменные файлы жёсткими ссылками: удаление папки освобождает только байты файлов с одним
        // именем, и окно называет именно их (судья 2026-11-21, круг 2: окно называло 13,7 ГБ, а освободилось бы 37 МБ). [NOT-TESTED]
        long freed = 0;
        bool shared = false;
        try
        {
            foreach (var f in new DirectoryInfo(dir).EnumerateFiles("*", SearchOption.AllDirectories))
                if (Delta.Links(f.FullName) > 1) shared = true; else freed += f.Length;
        }
        catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException) { }
        var ask = MessageBox.Show(form, Ui.F("box.oldbundle", dir, Ui.Size(freed), shared ? Ui.T("box.oldbundle.shared") : ""), Ui.T("box.oldbundle.title"),
                                  MessageBoxButtons.YesNo, MessageBoxIcon.Question, MessageBoxDefaultButton.Button2);
        if (ask != DialogResult.Yes) { MetalWindow.Log("папку прежней сборки оставили: " + dir); return; }
        ThreadPool.QueueUserWorkItem(_ =>
        {
            for (int i = 0; i < 20; i++)
            {
                // Delta.DeleteDir снимает «только для чтения» с файлов папки (архиватор с атрибутами DOS): Directory.Delete на таком файле отказывал все 20 раз.
                try { Delta.DeleteDir(dir); MetalWindow.Log("папка прежней сборки удалена: " + dir); return; }
                catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException) { Thread.Sleep(500); }
            }
            MetalWindow.Log("папка прежней сборки не удалилась целиком: " + dir);
        });
    }

    // Игра в прошлый раз упала — лаунчер на следующем запуске сам предлагает собрать отчёт (KUMM plans/55 B8, `[OWNER]` 2026-11-17 21:58 «было бы хорошо»).
    // Признак падения — папка в ConanSandbox\Saved\Crashes игры новее той, что лаунчер уже видел (файл в папке состояния лаунчера, по одному на папку игры;
    // первый запуск только запоминает). Каждое падение предлагается один раз, при любом ответе. [TESTED: 2026-11-18 · stand B16′ C1–C6 · KUMM
    // testcases/reports/2026-11-18_conan-launcher-b7-verification.md]
    static string CrashesSeenFile(string gameDir)
    {
        using (var sha = System.Security.Cryptography.SHA1.Create())
        {
            var h = sha.ComputeHash(System.Text.Encoding.UTF8.GetBytes(Path.GetFullPath(gameDir).TrimEnd('\\').ToLowerInvariant()));
            return Path.Combine(State.Dir(), "crashes-" + BitConverter.ToString(h, 0, 4).Replace("-", "").ToLowerInvariant() + ".seen");
        }
    }

    // Сборщик отчёта с папкой игры: «D:\» в кавычках съел бы кавычку, поэтому корень диска передаётся как «D:\.» (судья 2026-11-18, риск 4).
    internal static void StartReport(IWin32Window owner, string reportCmd, string gameDir)
    {
        string args = gameDir == null ? "" : "-GameDir \"" + (gameDir.EndsWith("\\") ? gameDir + "." : gameDir) + "\"";
        if (Start(reportCmd, args)) return;
        MetalWindow.Log("collect_report.cmd не запустился: отчёт не собран");
        MessageBox.Show(owner, Ui.T("box.report.fail"), Ui.T("box.crash.title"), MessageBoxButtons.OK, MessageBoxIcon.Warning);
    }

    internal static void OfferCrashReport(Form form, string gameDir, string reportCmd, string packVersion, string gameVersion)
    {
        if (gameDir == null) return;
        string crashes = Path.Combine(gameDir, "ConanSandbox", "Saved", "Crashes"), seenFile;
        try { seenFile = CrashesSeenFile(gameDir); }
        catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException || ex is NotSupportedException || ex is ArgumentException)
        { MetalWindow.Log("папка состояния лаунчера недоступна: " + ex.Message); return; }
        DirectoryInfo newest = null;
        try
        {
            if (Directory.Exists(crashes))
                foreach (var d in new DirectoryInfo(crashes).EnumerateDirectories())
                    if (newest == null || d.CreationTimeUtc > newest.CreationTimeUtc) newest = d;
        }
        catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException) { MetalWindow.Log("папка отчётов о падениях не прочитана: " + ex.Message); return; }
        string stamp = newest == null ? "нет" /* ui-ok: a state-file stamp, never shown */ : newest.Name + "|" + newest.CreationTimeUtc.Ticks, seen = null;
        try { if (File.Exists(seenFile)) seen = File.ReadAllText(seenFile).Trim(); }
        catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException) { }
        if (seen == stamp) { MetalWindow.Log("отчёты о падениях: новых падений нет"); return; }
        try { File.WriteAllText(seenFile, stamp); }
        catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException) { MetalWindow.Log("отметка падений не записана: " + ex.Message); return; }
        long seenTicks = 0;
        if (seen != null && seen.Contains("|")) long.TryParse(seen.Substring(seen.LastIndexOf('|') + 1), out seenTicks);
        if (seen == null || newest == null || newest.CreationTimeUtc.Ticks <= seenTicks) { MetalWindow.Log("отчёты о падениях: запомнил последний (" + stamp + ")"); return; }
        MetalWindow.Log("падение " + newest.Name + ": предлагаю отчёт");
        var ask = MessageBox.Show(form, Ui.T("box.crash"), Ui.T("box.crash.title"), MessageBoxButtons.YesNo, MessageBoxIcon.Question, MessageBoxDefaultButton.Button1);
        if (ask != DialogResult.Yes) { MetalWindow.Log("падение " + newest.Name + ": игрок отказался от отчёта"); return; }
        MetalWindow.Log("падение " + newest.Name + ": собираю отчёт");
        if (File.Exists(reportCmd)) StartReport(form, reportCmd, gameDir);
        else MetalWindow.Log("collect_report.cmd рядом с лаунчером нет: отчёт не собран");
        Open("https://github.com/" + BuildInfo.FeedRepo + "/issues/new?title=" + Uri.EscapeDataString(Ui.F("box.crash.issue", packVersion, gameVersion)));
    }

    // Надписи таблички переносятся по ширине, которую ей оставляет окно.
    internal static void FitWidth(Control parent, int width)
    {
        foreach (Control c in parent.Controls)
        {
            if (c is OutlinedLabel lbl && c.Parent == parent && !(parent is FlowLayoutPanel f && f.FlowDirection == FlowDirection.LeftToRight))
                lbl.MaximumSize = new Size(width - parent.Padding.Horizontal, 0);
            if (c is FlowLayoutPanel p && p.FlowDirection == FlowDirection.TopDown) FitWidth(p, width - parent.Padding.Horizontal);
        }
    }

    internal static Bitmap LoadBitmap(string name)
    {
        using (var s = Assembly.GetExecutingAssembly().GetManifestResourceStream(name))
        {
            if (s == null) return null;
            using (var img = Image.FromStream(s))
            {
                var bmp = new Bitmap(img.Width, img.Height, PixelFormat.Format32bppPArgb);
                using (var g = Graphics.FromImage(bmp)) g.DrawImage(img, 0, 0, img.Width, img.Height);
                return bmp;
            }
        }
    }
}

// Окно и то, что в нём видно, — из фактов: найденная игра (папка, номер сборки Funcom, что в ней стоит), лента выпусков, файлы сборки рядом, идущее
// дело (Job). Экран выбирается заново на каждом событии (Refresh) — окна, в котором одно противоречит другому, не бывает (plans/57, критерий 9;
// кадр 08:12: «Игра не найдена» вместе с «Удалить сборку» и живой «Играть»). [NOT-TESTED]
sealed class Launcher
{
    public readonly MetalWindow Form = new MetalWindow();
    readonly string here = KrinikConanLauncher.Here;
    readonly MetalButton main = KrinikConanLauncher.ColumnButton(), cancel = KrinikConanLauncher.ColumnButton(), guide = KrinikConanLauncher.ColumnButton(),
                         feedback = KrinikConanLauncher.ColumnButton(), uninstall = KrinikConanLauncher.ColumnButton(),
                         gameNotes = new MetalButton { Cursor = Metal.Hand }, packNotes = new MetalButton { Cursor = Metal.Hand };
    readonly StatePanel panel = new StatePanel();
    readonly UpdatePlate plate = new UpdatePlate();
    readonly ChooserOverlay chooser = new ChooserOverlay();
    readonly LangSwitch lang = new LangSwitch();
    readonly ReportPlaque report = new ReportPlaque { Padding = new Padding(18, 14, 18, 14), Margin = Padding.Empty, Visible = false };
    readonly List<(OutlinedLabel label, Func<string> text)> reportTexts = new List<(OutlinedLabel, Func<string>)>();
    readonly MetalButton collect = KrinikConanLauncher.BigButton("");
    readonly System.Windows.Forms.Timer tick = new System.Windows.Forms.Timer { Interval = 250 };
    readonly Meter meter = new Meter();
    readonly string reportCmd = Path.Combine(KrinikConanLauncher.Here, KrinikConanLauncher.REPORT_CMD);

    GameCopy game;
    List<GameCopy> copies = new List<GameCopy>();
    bool searching, feedDone, offered;
    // Окно удаления сборки, которое открыл лаунчер; пока оно живо — экран «removing» без «Играть» и «Удалить сборку» (судья 2026-11-18, находка 5:
    // «Играть» запускало игру посреди возврата файлов, второе «Удалить сборку» — второе удаление). [NOT-TESTED]
    Process uninstalling;
    readonly Games.Progress searchProgress = new Games.Progress();
    Feed.Answer feed;
    Job job;
    Job.Stage shownStage;
    double stageStart;
    volatile bool stop;
    Action mainAction;
    string screen = "";
    int frame;
    double lastFrame = -10;

    string UninstallName => Bundle.UninstallCmd(here);
    const string STOP_MARK = BuildUpdate.STOP_MARK;

    public Launcher()
    {
        Form.Icon = KrinikConanLauncher.AppIcon();
        Form.LauncherVersion = BuildInfo.LauncherVersion;
        main.Gold = true;
        plate.FrameH = Form.FrameH; plate.FrameV = Form.FrameV;
        Form.SetParts(new[] { main, cancel, guide, feedback, uninstall }, panel, plate, lang, chooser, gameNotes, packNotes);
        BuildReport();
        Form.Aside = report;
        Form.Controls.Add(report);
        Form.DragBy(report);
        Form.DragBy(plate);

        main.Click += (s, e) => mainAction?.Invoke();
        cancel.Click += (s, e) => { stop = true; cancel.Enabled = false; MetalWindow.Log("нажата «Отменить»"); };
        guide.Click += (s, e) => { var pdf = GuidePdf(); if (pdf != null) Process.Start(new ProcessStartInfo(pdf) { UseShellExecute = true }); };
        // «Отзыв» открывает и закрывает табличку; замер нажатия и кадр таблички — для стенда (кейс perf-report, баг 110: владелец 2026-11-22 15:06 назвал
        // это окно медленным). [NOT-TESTED]
        feedback.Click += (s, e) =>
        {
            using (MetalWindow.Perf("Feedback.Toggle")) report.Visible = !report.Visible;
            MetalWindow.Log("отзыв: табличка " + (report.Visible ? "открыта" : "закрыта") + " · окно " + Form.ClientSize.Width + "x" + Form.ClientSize.Height);
            SaveFrame(screen + (report.Visible ? "-report" : "-noreport"));
        };
        uninstall.Click += (s, e) => Uninstall();
        gameNotes.Click += (s, e) => KrinikConanLauncher.Open(Bundle.GameNotes(here));
        packNotes.Click += (s, e) => KrinikConanLauncher.Open(BuildRelease()?.Page is string page && page.Length > 0 ? page : feed?.Build?.Page ?? Feed.LatestBuildPage);
        plate.BuildButton.Click += (s, e) => UpdateBuild();
        plate.LauncherButton.Click += (s, e) => UpdateLauncher();
        chooser.Ok.Click += (s, e) => Picked();
        chooser.List.Chosen += Picked;
        chooser.List.AccessibleRole = AccessibleRole.List;
        chooser.Cancel.Click += (s, e) => { chooser.Close(); MetalWindow.Log("выбор копии закрыт без выбора"); Refresh(); };
        lang.Picked += l => Ui.Set(l);
        // Кадр раскрытого списка — для сверки с экраном «language» макета; окно ушло в фон — список закрывается, как у выпадающих списков Windows.
        lang.Opened += () => SaveFrame(screen + "-langlist");
        Form.Deactivate += (s, e) => lang.Close();
        Ui.Changed += () => { Refresh(); Form.Relayout(); MetalWindow.Log("экран после смены языка: " + screen + " · " + panel.TextForLog()); SaveFrame(screen + "-lang"); };
        tick.Tick += (s, e) => Tick();

        // Пока идёт установка или обновление, окно не закрывается: закрытие посреди снятия сборки оставило бы игру без сборки (судья 2026-11-17).
        Form.FormClosing += (s, e) =>
        {
            if (!Form.Busy || e.CloseReason == CloseReason.WindowsShutDown) return;
            e.Cancel = true;
            MessageBox.Show(Form, Ui.T("box.busy"), Ui.T("box.busy.title"), MessageBoxButtons.OK, MessageBoxIcon.Information);
        };
        // Через 3 с после показа окна — «жив»: сигнал ждущему прежнему лаунчеру или коммит самообновления (SelfUpdate.Settled); закрытое раньше — тоже «жив».
        Form.Shown += (s, e) => SelfUpdate.Settled();
        Form.FormClosed += (s, e) => SelfUpdate.Closed(e.CloseReason);
        Form.Shown += (s, e) => Form.BeginInvoke((Action)(() => { KrinikConanLauncher.OfferOldBundle(Form); OfferCrash(); }));

        // Игра: лаунчер в её папке → она; выбранная раньше → она; иначе поиск по дискам (в фоне, у снимка — сразу).
        string dir = Games.Around(here) ?? Games.Chosen();
        if (dir != null) { game = Games.Describe(dir, UninstallName); copies.Add(game); MetalWindow.Log("игра: " + dir + " · CL " + game.Cl + " · " + game.Kind); }
        if (MetalWindow.SnapshotMode)
        {
            if (game == null) FinishSearch(Games.Search(searchProgress, () => false));
            feed = KrinikConanLauncher.ReadFeed(); feedDone = true;
        }
        else
        {
            // Поиск — после показа окна: его итог приходит в окно через BeginInvoke, а до показа у окна нет дескриптора, и итог пропал бы.
            if (game == null) { searching = true; Form.Shown += (s, e) => StartSearch(); }
            Form.Shown += (s, e) => ReadFeedAsync();
        }
        Refresh();
    }

    // --- тексты

    void BuildReport()
    {
        Func<string> mail = () =>
        {
            var link = Array.Find(BuildInfo.AuthorLinks, l => l.Url.StartsWith("mailto:", StringComparison.OrdinalIgnoreCase));
            return link != null ? Ui.F("report.3.mail", link.Label) : Ui.T("report.3");
        };
        foreach (var (key, pt, style, color, family) in new[]
        {
            ("report.title", 14f, FontStyle.Bold, KrinikConanLauncher.Gold, "Georgia"), ("report.1", 11f, FontStyle.Regular, KrinikConanLauncher.Ink, "Segoe UI"),
            ("report.2", 11f, FontStyle.Regular, KrinikConanLauncher.Ink, "Segoe UI"), ("report.3", 11f, FontStyle.Regular, KrinikConanLauncher.Ink, "Segoe UI"),
            ("report.4", 11f, FontStyle.Regular, KrinikConanLauncher.Ink, "Segoe UI"), ("report.note", 10f, FontStyle.Regular, KrinikConanLauncher.Muted, "Segoe UI")
        })
        {
            var l = KrinikConanLauncher.Text("", pt, style, color, family);
            string k = key;
            reportTexts.Add((l, k == "report.3" ? mail : (Func<string>)(() => Ui.T(k))));
            report.Controls.Add(l);
        }
        collect.Margin = new Padding(0, 6, 0, 0);
        collect.Enabled = File.Exists(reportCmd);
        collect.Click += (s, e) => KrinikConanLauncher.StartReport(Form, reportCmd, game?.Dir);
        report.Controls.Add(collect);
    }

    // Все слова окна — из таблицы на текущем языке (Ui); зовётся на каждом Refresh: смена языка перерисовывает окно целиком, без перезапуска.
    void ApplyTexts()
    {
        string pack = PackShown(), gv = GameShown();
        Form.Text = Ui.F("window.title", pack, gv);
        Form.Title = Ui.F("head.title", pack);
        Form.GameName = "Conan Exiles Enhanced " + gv;
        Form.GameVersion = gv;
        Form.PackVersion = pack;
        Form.LauncherLine = Ui.F("launcher.version", BuildInfo.LauncherVersion);
        Form.Links = Array.ConvertAll(BuildInfo.AuthorLinks, l => new BuildInfo.Link(Ui.LinkText(l.Text), l.Label, l.Url));
        Form.Retext();
        guide.Text = Ui.T("btn.guide"); feedback.Text = Ui.T("btn.feedback"); uninstall.Text = Ui.T("btn.uninstall"); cancel.Text = Ui.T("btn.stop");
        gameNotes.Text = packNotes.Text = Ui.T("notes");
        plate.BuildButton.Text = Ui.T("btn.update"); plate.LauncherButton.Text = Ui.T("btn.update.launcher");
        chooser.Ok.Text = Ui.T("btn.install"); chooser.Cancel.Text = Ui.T("m.cancel"); chooser.List.AccessibleName = chooser.List.Text = Ui.T("m.list");
        foreach (var (label, text) in reportTexts) label.Text = text();
        collect.Text = Ui.T("report.collect");
        lang.Retext();
    }

    // Шапка и заголовок окна называют сборку и игру, ДЛЯ КОТОРОЙ она собрана, одной парой (макеты, принятые владельцем 2026-11-18 15:03: на экране
    // «noversion» с игрой 3.2.0 шапка остаётся «0.9.1 · 3.1.1»). Номер найденной игры живёт в списке состояния. Прежде номер игры брался у найденной
    // копии отдельно от номера сборки, и заголовок складывался в «0.9.1 для Conan Exiles Enhanced 3.0.1» (судья 2026-11-18, находка 4). У поставленной
    // сборки номер игры — из манифеста её папки в игре (GameCopy.BuildGame): прежде он брался у найденной копии, и после обновления игры Funcom шапка
    // называла «0.9.1 для 3.2.0», а при ответе ленты (Games.Learn) номер игры в заголовке менялся (судья 2026-11-18, круг 2, находка 3). [NOT-TESTED]
    (string pack, string game) Shown()
    {
        // Папки Krinik_* поставленной сборки в игре нет (запись есть, папку удалили) — номер игры берётся у самого лаунчера, если он из того же выпуска;
        // номер найденной копии — последним: после обновления игры он пары с этой сборкой не составляет (судья 2026-11-20, круг 3, находка 3). [NOT-TESTED]
        // Номера сравниваются как номера выпусков, а не как строки: BuildVersion уже приведён (ReleaseNumber.ToString), а манифест лаунчера — как записан,
        // и «0.9.1-rc1» или «1.0» с «0.9.1-RC1» / «1.0.0» строкой не совпали бы (судья 2026-11-20, круг 4, находка 7). [NOT-TESTED]
        if (game != null && game.Kind == CopyKind.Krinik && game.BuildVersion != null)
        {
            var mine = Feed.ParseVersion(Bundle.PackVersion(here));
            bool sameRelease = mine != null && mine == Feed.ParseVersion(game.BuildVersion);
            return (game.BuildVersion, game.BuildGame ?? (sameRelease ? Bundle.GameVersion(here) : null) ?? game.Version ?? Bundle.GameVersion(here));
        }
        var r = BuildRelease();
        if (r != null && (game == null || game.Kind != CopyKind.Krinik) && BuildUpdate.LocalBundle(here) == null)
            return (r.Number.ToString(), r.GameVersion ?? game?.Version ?? Bundle.GameVersion(here));
        return (Bundle.PackVersion(here), Bundle.GameVersion(here));
    }

    string PackShown() => Shown().pack;
    string GameShown() => Shown().game;
    string GameVersionText(GameCopy c) => c.Version ?? Ui.F("v.cl", c.Cl);
    Feed.Release BuildRelease() => game != null ? feed?.BuildFor(game.Cl) : null;

    string GuidePdf()
    {
        var name = Bundle.GuidePdf(here);
        var pdf = Path.Combine(here, name);
        if (File.Exists(pdf)) return pdf;
        if (game != null)
            try { foreach (var d in Directory.EnumerateDirectories(game.Dir, "Krinik_*")) { var f = Path.Combine(d, Bundle.GuidePdf(d)); if (File.Exists(f)) return f; } }
            catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException) { }
        return null;
    }

    // --- экран

    void Refresh() { using (MetalWindow.Perf("Launcher.Refresh")) RefreshNow(); }

    void RefreshNow()
    {
        if (Form.IsDisposed) return;
        if (game != null && job == null) game = Games.Describe(game.Dir, UninstallName);   // после установки и удаления копия другая
        ApplyTexts();
        var rows = new List<StatePanel.Row>();
        string id, what = null;
        int percent = 0;
        MetalButton gold = null;
        bool goldOn = true;
        var mid = new List<MetalButton>();
        var low = new List<MetalButton> { guide, feedback };
        mainAction = null;
        string plateBuild = null, plateBuildNo = null, plateLauncher = null;

        if (job != null) id = JobScreen(rows, out what, out percent, mid);
        else if (searching)
        {
            id = "search";
            what = Ui.T("p.search");
            SearchRows(rows, out percent);
        }
        else if (game == null && copies.Count > 1)
        {
            id = "choose";
            gold = main; main.Text = Ui.T("btn.install"); goldOn = !chooser.Visible; mainAction = OpenChooser;
            rows.Add(new StatePanel.Row(Ui.T("st.search"), Ui.T("v.search.done")));
            rows.Add(new StatePanel.Row(Ui.T("st.copies"), copies.Count.ToString()));
        }
        else if (game == null)
        {
            id = "notfound";
            gold = main; main.Text = Ui.T("btn.pick"); mainAction = PickFolder;
            rows.Add(new StatePanel.Row(null, Ui.T("v.notfound"), warn: true));
            rows.Add(new StatePanel.Row(null, Ui.T("v.pick.hint")));
        }
        else if (Uninstalling())
        {
            id = "removing";
            rows.Add(new StatePanel.Row(null, Ui.T("v.removing")));
        }
        else if (game.Kind == CopyKind.Krinik)
        {
            // Сборка стоит: «Играть» и «Удалить сборку», списка состояния нет (`[OWNER]` 2026-11-18 10:18–10:19). Новее для этой игры — плашка.
            gold = main; main.Text = Ui.T("btn.play"); mainAction = Play;
            low.Add(uninstall);
            var r = BuildRelease();
            string installed = game.BuildVersion ?? Bundle.PackVersion(here);
            id = "installed";
            // Сборка в запретной папке (never.txt): «Играть» и «Удалить сборку» остаются, плашки обновления нет — каждое «Обновить сборку» кончалось бы
            // отказом u.never (судья 2026-11-20, круг 3, находка 4). [NOT-TESTED]
            if (Games.Never(game.Dir)) r = null;
            if (r != null && Feed.Newer(r.Number, installed)) { id = "update"; plateBuild = Ui.T("plate.build").Replace("{1}", r.GameVersion ?? GameShown()); plateBuildNo = r.Number.ToString(); }
        }
        else id = FoundScreen(rows, ref gold, ref goldOn);

        // Вышел лаунчер новее — строка и кнопка на плашке, пока не идёт другое дело и не открыт выбор копии.
        if (job == null && !searching && !chooser.Visible && feed?.Launcher != null && Feed.Newer(feed.Launcher.Number, BuildInfo.LauncherVersion))
            plateLauncher = Ui.T("plate.launcher");
        plate.Set(plateBuild, plateBuildNo, plateLauncher, feed?.Launcher?.Number?.ToString());

        panel.Set(what, percent, rows);
        // Под выбором копии кнопки окна не нажимаются (выбор модальный); «Руководство» светится, только когда PDF руководства есть рядом или в
        // папке установленной сборки (прежнее правило лаунчера, 2026-11-01).
        bool modal = chooser.Visible;
        guide.Enabled = !modal && GuidePdf() != null;
        feedback.Enabled = uninstall.Enabled = !modal;
        Form.SetColumn(gold, goldOn, panel, mid, low);
        if (id != screen)
        {
            screen = id;
            MetalWindow.Log($"экран: {id} · {panel.TextForLog()}");
            SaveFrame(id);
        }
    }

    // Игра найдена, сборки в ней нет: что лежит рядом с лаунчером и что есть в ленте для версии этой игры.
    string FoundScreen(List<StatePanel.Row> rows, ref MetalButton gold, ref bool goldOn)
    {
        rows.Add(new StatePanel.Row(Ui.T("st.folder"), game.Dir, path: true));
        rows.Add(new StatePanel.Row(Ui.T("st.version"), GameVersionText(game)));
        // Запретная папка (never.txt) не получает предложения поставить сборку. Игру вокруг лаунчера (Games.Around) поиск не проверял: сборка,
        // распакованная в эталонную копию, предлагала «Установить сборку», и каждое нажатие кончалось сообщением u.never (судья 2026-11-18, круг 2,
        // находка 9). Экран тот же, что дала бы лента: «release-bad» с причиной. [NOT-TESTED]
        if (Games.Never(game.Dir))
        {
            rows.Add(new StatePanel.Row(null, Ui.T("u.never"), warn: true));
            return "release-bad";
        }
        // Сборка, распакованная рядом с лаунчером, — для этой версии игры (launcher.gameVersion её манифеста): ставится без ленты и без сети.
        var local = BuildUpdate.LocalBundle(here);
        if (local != null && game.Version != null && Bundle.GameVersion(here) == game.Version)
        {
            gold = main; main.Text = Ui.T("btn.install"); mainAction = InstallLocal;
            rows.Add(new StatePanel.Row(Ui.T("st.build"), Ui.F("v.build.for", Bundle.PackVersion(here), game.Version)));
            rows.Add(new StatePanel.Row(Ui.T("st.files"), Ui.T("v.files.beside")));
            return "found-files";
        }
        if (!feedDone)
        {
            gold = main; main.Text = Ui.T("btn.install"); goldOn = false;
            rows.Add(new StatePanel.Row(Ui.T("st.build"), Ui.T("v.feed.wait")));
            return "feed-wait";
        }
        if (feed == null)
        {
            gold = main; main.Text = Ui.T("btn.retry"); mainAction = ReadFeedAsync;
            rows.Add(new StatePanel.Row(null, Ui.T("v.feed.none"), warn: true));
            return "offline";
        }
        var r = BuildRelease();
        if (r == null)
        {
            // Для этой версии игры сборки нет: окно называет последнюю сборку и её игру и ничего не ставит (критерий 6).
            rows.Add(new StatePanel.Row(null, Ui.F("v.noversion", GameVersionText(game)), warn: true));
            var latest = feed.Build;
            if (latest != null) rows.Add(new StatePanel.Row(Ui.T("st.latest"), latest.GameVersion != null ? Ui.F("v.build.for", latest.Number, latest.GameVersion) : latest.Number.ToString()));
            return "noversion";
        }
        var u = BuildUpdate.Prepare(r, game.Dir, here, out var why);
        if (u == null)
        {
            rows.Add(new StatePanel.Row(null, why, warn: true));
            return "release-bad";
        }
        gold = main; mainAction = () => Install(r, false);
        rows.Add(new StatePanel.Row(Ui.T("st.build"), Ui.F("v.build.for", r.Number, r.GameVersion ?? game.Version)));
        if (u.Beside || u.Ready)
        {
            main.Text = Ui.T("btn.install");
            // Части рядом с лаунчером — «уже лежат рядом»; архив уже распакован в папку игры — так и сказано (судья 2026-11-18, мелочь 15).
            rows.Add(new StatePanel.Row(Ui.T("st.files"), Ui.T(u.Beside ? "v.files.beside" : "v.files.unpacked")));
            return "found-files";
        }
        if (u.Have > 0)
        {
            // Скачано не всё — части сохранены (критерий 8). Причину пишет метка папки частей: «net» — оборвалась связь, «user» — игрок нажал «Остановить»,
            // «error» — ошибка (диск полон, части дважды не сошлись). Метки нет — лаунчер закрыли посреди скачивания или компьютер перезагрузился: окно
            // говорит только, что скачивание не закончено (судья 2026-11-18, находка 3: любое недокачанное называлось обрывом связи). [NOT-TESTED]
            string why2 = StopReason(u.PartsDir);
            rows.Clear();
            main.Text = Ui.T("btn.resume");
            string said = why2 == "user" ? "v.user.stop" : why2 == "net" ? "v.net.stop" : why2 == "error" ? "v.error.stop" : "v.unfinished.stop";
            rows.Add(new StatePanel.Row(null, Ui.T(said), warn: why2 != "user"));
            rows.Add(new StatePanel.Row(Ui.T("st.downloaded"), Ui.Amount(u.Have, u.Total)));
            rows.Add(new StatePanel.Row(null, Ui.T("v.kept")));
            return why2 == "user" ? "paused" : why2 == "net" ? "neterror" : why2 == "error" ? "dlerror" : "unfinished";
        }
        main.Text = Ui.T("btn.install");
        rows.Add(new StatePanel.Row(Ui.T("st.files"), Ui.T("v.files.github")));
        // По списку файлов размер скачивания известен только после сверки папки игры: строка не называет ни 0,1 МБ выпуска без частей, ни весь архив
        // при повторной установке, где скачается один список (судья, круг 5, дефект 1).
        rows.Add(new StatePanel.Row(Ui.T("st.need"), u.ByManifest && !u.Ready ? Ui.T("v.need.after") : Ui.Size(u.Total)));
        return "found-nofiles";
    }

    // Метка причины остановки; нет метки или её не прочесть — «unfinished».
    static string StopReason(string partsDir)
    {
        try { var f = Path.Combine(partsDir, STOP_MARK); return File.Exists(f) ? File.ReadAllText(f).Trim() : "unfinished"; }
        catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException) { return "unfinished"; }
    }

    static void WriteStopMark(BuildUpdate u, string reason)
    {
        if (u.PartsDir != null && !u.Beside && Directory.Exists(u.PartsDir))
            try { File.WriteAllText(Path.Combine(u.PartsDir, STOP_MARK), reason); } catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException) { }
    }

    void SearchRows(List<StatePanel.Row> rows, out int percent)
    {
        int done = searchProgress.DrivesDone, total = Math.Max(1, searchProgress.DrivesTotal);
        percent = done * 100 / total;
        rows.Add(new StatePanel.Row(Ui.T("st.drives"), Ui.F("v.of", done, searchProgress.DrivesTotal)));
        string d = searchProgress.Drive ?? "";
        rows.Add(new StatePanel.Row(Ui.T("st.now"), d.Length == 1 ? Ui.F("v.drive", d) : d, path: true));
    }

    string JobScreen(List<StatePanel.Row> rows, out string what, out int percent, List<MetalButton> mid)
    {
        var st = job.Now;
        string v = job.Version;
        double elapsed = job.Clock.Elapsed.TotalSeconds - stageStart;
        percent = job.Percent;
        string elapsedText = Ui.Duration(TimeSpan.FromSeconds(elapsed));
        switch (st)
        {
            case Job.Stage.Download:
            case Job.Stage.Launcher:
                what = st == Job.Stage.Launcher ? Ui.F("p.launcher", v) : job.Update ? Ui.F("p.update", v) : Ui.F("p.download", v);
                rows.Add(new StatePanel.Row(Ui.T("st.downloaded"), Ui.Amount(job.Done, job.Total)));
                rows.Add(new StatePanel.Row(Ui.T("st.speed"), meter.Speed.HasValue ? Ui.Speed(meter.Speed.Value) : Ui.T("v.speed.wait")));
                rows.Add(new StatePanel.Row(Ui.T("st.left"), meter.Left.HasValue ? Ui.Duration(meter.Left.Value) : Ui.T("v.left.wait")));
                rows.Add(new StatePanel.Row(Ui.T("st.elapsed"), elapsedText));
                if (st == Job.Stage.Download) mid.Add(cancel);
                return st == Job.Stage.Launcher ? "launcher" : job.Update ? "updating" : "download";
            case Job.Stage.Verify:
                what = job.Update ? Ui.F("p.update", v) : Ui.F("p.verify", v);
                rows.Add(new StatePanel.Row(Ui.T("st.checked"), Ui.Amount(job.Done, job.Total)));
                rows.Add(new StatePanel.Row(Ui.T("st.elapsed"), elapsedText));
                mid.Add(cancel);
                return job.Update ? "updating-verify" : "verify";
            case Job.Stage.Unpack:
            case Job.Stage.Copy:
                // Copy — файлы прежней сборки копируются в новую там, где диск не даёт жёстких ссылок (флешка, exFAT): та же полоса, своя подпись строки.
                what = job.Update ? Ui.F("p.update", v) : Ui.F("p.unpack", v);
                rows.Add(new StatePanel.Row(Ui.T(st == Job.Stage.Copy ? "st.copied" : "st.unpacked"), Ui.Amount(job.Done, job.Total)));
                rows.Add(new StatePanel.Row(Ui.T("st.elapsed"), elapsedText));
                mid.Add(cancel);
                return st == Job.Stage.Copy ? (job.Update ? "updating-copy" : "copy") : job.Update ? "updating-unpack" : "unpack";
            case Job.Stage.Remove:
                what = job.Update ? Ui.F("p.update", v) : Ui.T("p.remove");
                percent = 0;
                rows.Add(new StatePanel.Row(Ui.T("st.elapsed"), elapsedText));
                rows.Add(new StatePanel.Row(null, Ui.T("v.keep.open")));
                return job.Update ? "updating-remove" : "remove";
            default:
                what = job.Update ? Ui.F("p.update", v) : Ui.F("p.install", v);
                percent = job.ModsTotal > 0 ? Math.Min(100, job.ModsDone * 100 / job.ModsTotal) : 0;
                rows.Add(new StatePanel.Row(Ui.T("st.mods"), Ui.F("v.of", job.ModsDone, job.ModsTotal)));
                rows.Add(new StatePanel.Row(Ui.T("st.elapsed"), elapsedText));
                rows.Add(new StatePanel.Row(null, Ui.T("v.keep.open")));
                return job.Update ? "updating-install" : "install";
        }
    }

    // Таймер окна: пока идёт дело или поиск — числа полосы; новый этап — весь экран заново (другие строки, другие кнопки).
    void Tick()
    {
        if (job != null)
        {
            if (job.Now != shownStage) { shownStage = job.Now; stageStart = job.Clock.Elapsed.TotalSeconds; meter.Reset(); Refresh(); return; }
            if (job.Now == Job.Stage.Download || job.Now == Job.Stage.Launcher)
                meter.Sample(job.Done - Math.Max(0, job.SessionStart), job.Total - Math.Max(0, job.SessionStart), job.Clock.Elapsed.TotalSeconds);
        }
        else if (!searching) { tick.Stop(); return; }
        var rows = new List<StatePanel.Row>();
        string what; int percent;
        if (job != null) JobScreen(rows, out what, out percent, new List<MetalButton>());
        else { what = Ui.T("p.search"); SearchRows(rows, out percent); }
        if (panel.Set(what, percent, rows)) Form.Relayout();
        double t = job?.Clock.Elapsed.TotalSeconds ?? 0;
        if (Frames.On && job != null && t - lastFrame >= Frames.EVERY_S) { lastFrame = t; SaveFrame(screen + "_t" + (int)t); }
    }

    void SaveFrame(string name)
    {
        if (!Frames.On) return;
        // Экран, выбранный до первого показа окна, снимается сразу после него: до показа у окна нет ни раскладки, ни кэша картины.
        if (!Form.IsHandleCreated) { Form.Shown += (s, e) => SaveFrame(name); return; }
        string file = Path.Combine(Frames.Dir, $"{++frame:000}_{name}_{(Ui.Current == Ui.Lang.Ru ? "ru" : "en")}.png");
        Form.BeginInvoke((Action)(() =>
        {
            try { Form.SaveSnapshot(file); MetalWindow.Log("кадр " + Path.GetFileName(file) + ": " + panel.TextForLog()); }
            catch (Exception ex) when (ex is IOException || ex is ExternalException || ex is ArgumentException) { MetalWindow.Log("кадр не записан: " + ex.Message); }
        }));
    }

    // --- поиск и лента

    void StartSearch()
    {
        searching = true;
        tick.Start();
        MetalWindow.Log("ищу игру на дисках");
        ThreadPool.QueueUserWorkItem(_ =>
        {
            var dirs = Games.Search(searchProgress, () => Form.IsDisposed);
            var list = dirs.ConvertAll(d => Games.Describe(d, UninstallName));
            OnUi(() => { FinishSearch(dirs, list); Refresh(); if (game != null) OfferCrash(); if (copies.Count > 1) OpenChooser(); });
        });
    }

    void FinishSearch(List<string> dirs, List<GameCopy> list = null)
    {
        searching = false;
        copies = list ?? dirs.ConvertAll(d => Games.Describe(d, UninstallName));
        if (copies.Count == 1) { game = copies[0]; Games.Choose(game.Dir); }
    }

    void ReadFeedAsync()
    {
        feedDone = false;
        if (searching || job != null) { } else Refresh();
        ThreadPool.QueueUserWorkItem(_ =>
        {
            var answer = KrinikConanLauncher.ReadFeed();
            OnUi(() =>
            {
                feed = answer; feedDone = true;
                MetalWindow.Log($"лента: сборок {answer?.Builds.Count ?? 0}, новейшая {answer?.Build?.Number?.ToString() ?? "—"} (у нас {PackShown()}), " +
                                $"для этой игры {BuildRelease()?.Number?.ToString() ?? "—"}, лаунчер {answer?.Launcher?.Number?.ToString() ?? "—"} (у нас {BuildInfo.LauncherVersion})");
                if (chooser.Visible) FillChooser();
                if (job == null) Refresh();
            });
        });
    }

    void OnUi(Action act)
    {
        if (Form.IsDisposed || !Form.IsHandleCreated) return;
        try { Form.BeginInvoke(act); } catch (Exception) { }   // окно уже уходит (судья, круг 2)
    }

    void OfferCrash()
    {
        if (offered || game == null) return;
        offered = true;
        // В отчёт о падении — версия той копии игры, что упала, а не игры, для которой собрана сборка из шапки.
        KrinikConanLauncher.OfferCrashReport(Form, game.Dir, reportCmd, PackShown(), GameVersionText(game));
    }

    // --- выбор игры

    void OpenChooser()
    {
        FillChooser();
        chooser.List.Selected = 0;
        chooser.Visible = true;     // главная кнопка под выбором гаснет
        Refresh();
        chooser.Open(Form.Picture(chooser));
        Form.Relayout();
        SaveFrame("choose-modal");
    }

    // Строки списка копий: что стоит в каждой и какая сборка ей подойдёт. Лента могла ответить позже, чем открылся выбор, — тогда строки
    // заполняются заново (стенд 2026-11-18 15:46: копия 3.0.1 осталась без «сборка для этой версии ещё не вышла»). [NOT-TESTED]
    void FillChooser()
    {
        chooser.Title = Ui.F("m.title", copies.Count);
        chooser.Text2 = Ui.T("m.text");
        chooser.List.Items.Clear();
        foreach (var c in copies)
        {
            // Что стоит в копии; копии другой версии игры — и какая сборка ей подойдёт (макет 75b310e: «без модов, подойдёт сборка 0.9.0»).
            string state = c.Kind == CopyKind.Krinik ? (c.BuildVersion != null ? Ui.F("m.krinik", c.BuildVersion) : Ui.T("m.krinik.any"))
                         : c.Kind == CopyKind.OtherMods ? Ui.T("m.other") : Ui.T("m.clean");
            var r = feed?.BuildFor(c.Cl);
            if (feed != null && r == null) state = Ui.T("m.none");
            else if (r != null && feed.Build != null && r != feed.Build && c.Kind != CopyKind.Krinik) state = Ui.F("m.fits", state, r.Number);
            chooser.List.Items.Add(new CopyList.Item { Name = "Conan Exiles " + GameVersionText(c), State = state, Path = c.Dir });
        }
        chooser.List.Invalidate();
        MetalWindow.Log((feed == null ? "выбор копии (лента ещё не ответила): " : "выбор копии: ") + copies.Count + " копий: " + string.Join(" | ", chooser.List.Items.ConvertAll(i => i.Name + " · " + i.State + " · " + i.Path)));
    }

    // Выбор сделан: копия запоминается, и, если сборку в неё можно поставить, установка начинается — кнопка выбора так и называется («Установить сборку»).
    void Picked()
    {
        int i = chooser.List.Selected;
        if (i < 0 || i >= copies.Count) return;
        game = copies[i];
        Games.Choose(game.Dir);
        chooser.Close();
        Refresh();
        if (screen == "found-files" || screen == "found-nofiles") mainAction?.Invoke();
    }

    // «Указать папку игры»: окно выбора папки Windows; папка без ConanSandbox.exe — сообщение и выбор снова.
    void PickFolder()
    {
        // Стенд кадров: окно выбора папки Windows ставит само, по центру экрана, — на экран владельца (наблюдатель стенда 2026-11-18 16:00). Стенд его не
        // открывает; что кнопка открывает это окно, видно один раз 15:4x (заголовок «Обзор папок» прочитан стендом).
        if (Frames.On) { MetalWindow.Log("окно выбора папки: стенд кадров, окно не показано"); return; }
        using (var dlg = new FolderBrowserDialog { Description = Ui.T("pick.title"), ShowNewFolderButton = false })
            while (dlg.ShowDialog(Form) == DialogResult.OK)
            {
                string dir = dlg.SelectedPath.TrimEnd('\\');
                if (File.Exists(Path.Combine(dir, Games.GAME_EXE)))
                {
                    Games.Choose(dir);
                    game = Games.Describe(dir, UninstallName);
                    copies = new List<GameCopy> { game };
                    Refresh();
                    OfferCrash();
                    return;
                }
                MessageBox.Show(Form, Ui.F("pick.wrong", dir), Ui.T("btn.pick"), MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
    }

    // --- дела

    void Play()
    {
        var started = Process.Start(new ProcessStartInfo(game.Exe) { WorkingDirectory = game.Dir });
        if (started != null) Form.Close();
    }

    void Uninstall()
    {
        var ask = MessageBox.Show(Form, Ui.T("box.uninstall.ask"), Ui.T("box.uninstall"), MessageBoxButtons.YesNo, MessageBoxIcon.Question, MessageBoxDefaultButton.Button2);
        if (ask != DialogResult.Yes) return;
        string cmd = Path.Combine(game.Dir, UninstallName);
        if (!File.Exists(cmd)) { Refresh(); return; }
        // Лаунчер остаётся открытым (`[OWNER]` 2026-11-02 08:36): когда окно удаления закрылось, окно смотрит на игру снова (HOUSE_RULES 26).
        // Стенд кадров запускает окно удаления скрытым: консоль не выходит на экран владельца (как окно выбора папки, PickFolder).
        var p = Process.Start(new ProcessStartInfo(cmd) { WorkingDirectory = game.Dir, UseShellExecute = true, WindowStyle = Frames.On ? ProcessWindowStyle.Hidden : ProcessWindowStyle.Normal });
        if (p == null) return;
        Children.Track(p);
        p.EnableRaisingEvents = true;
        string gameDir = game.Dir;
        p.Exited += (s, e) => OnUi(() => { uninstalling = null; MetalWindow.Log("окно удаления сборки закрыто"); ForgetLeftUninstaller(gameDir, cmd); Refresh(); });
        uninstalling = p;
        MetalWindow.Log("окно удаления сборки открыто");
        Refresh();
    }

    // Деинсталлятор стирает себя последней строкой, после «pause»: окно, закрытое крестиком, оставляло его в чистой игре (KUMM bugs/115). Без журнала
    // раскатки удаление прошло, и файл — наш остаток: двойной щелчок по нему не нашёл бы движка отката и до шаблона 2026-11-21 вывел бы ложное «Готово»
    // (судья, круг 4, находка 4). С журналом (удаление не завершено) файл остаётся: им игрок повторит удаление. [NOT-TESTED]
    static void ForgetLeftUninstaller(string gameDir, string cmd)
    {
        if (!File.Exists(cmd) || File.Exists(Games.JournalOf(gameDir))) return;
        try { File.Delete(cmd); MetalWindow.Log("удаление прошло, оставшийся деинсталлятор убран: " + cmd); }
        catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException) { MetalWindow.Log("оставшийся деинсталлятор не убран: " + ex.Message); }
    }

    bool Uninstalling()
    {
        try { return uninstalling != null && !uninstalling.HasExited; }
        catch (InvalidOperationException) { return false; }
    }

    void InstallLocal() => RunJob(BuildUpdate.PrepareLocal(game.Dir, here), false);

    void Install(Feed.Release r, bool update)
    {
        var u = BuildUpdate.Prepare(r, game.Dir, here, out var why);
        if (u == null) { MessageBox.Show(Form, why, Ui.T(update ? "box.update" : "box.install"), MessageBoxButtons.OK, MessageBoxIcon.Information); return; }
        RunJob(u, update);
    }

    void UpdateBuild()
    {
        var r = BuildRelease();
        if (r == null || job != null) return;
        var u = BuildUpdate.Prepare(r, game.Dir, here, out var why);
        if (u == null) { MessageBox.Show(Form, why, Ui.T("box.update"), MessageBoxButtons.OK, MessageBoxIcon.Information); return; }
        // По списку файлов размер скачивания известен только после сверки прежних сборок: вопрос задаёт RunJob после неё (box.delta.ask). [NOT-TESTED]
        if (u.ByManifest && !u.Ready) { RunJob(u, true); return; }
        string drive = Path.GetPathRoot(u.GameDir).TrimEnd('\\'), installed = game.BuildVersion ?? Bundle.PackVersion(here);
        string free = u.FreeKnown ? Ui.F("box.update.free", drive, Ui.Size(u.Free)) : "";
        string text = u.Ready ? Ui.F("box.update.ready", r.Number, u.BundleDir, installed, free)
                              : Ui.F("box.update.ask", r.Number, Ui.Size(u.Total), installed, u.Have > 0 ? Ui.F("box.update.have", Ui.Size(u.Have)) : "", free);
        if (MessageBox.Show(Form, text, Ui.T("box.update"), MessageBoxButtons.YesNo, MessageBoxIcon.Question, MessageBoxDefaultButton.Button1) != DialogResult.Yes) return;
        RunJob(u, true);
    }

    void RunJob(BuildUpdate u, bool update)
    {
        string title = Ui.T(update ? "box.update" : "box.install");
        if (u.FreeKnown && u.Free < u.Need)
        {
            MessageBox.Show(Form, Ui.F("box.space", Path.GetPathRoot(u.GameDir).TrimEnd('\\'), Ui.Size(u.Need), Ui.Size(u.Free)), title, MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }
        if (!KrinikConanLauncher.UpdateAllowed(Form, title)) return;
        stop = false;
        job = new Job { Update = update, Version = u.Version };
        // Первый этап — настоящий: новый Job стоит на первом значении перечня, и окно до первого такта таймера рисовало «Установку» вместо
        // скачивания (стенд 2026-11-18 15:47: обрыв на первых 30 000 байт так и не показал полосу скачивания). [NOT-TESTED]
        // По списку файлов размер ещё не известен: полоса начинается с нуля, без размера архива (судья 2026-11-21, косметика).
        if (u.ByManifest && !u.Ready) job.Enter(Job.Stage.Download, 0, 0);
        else job.Enter(u.Local != null || u.Ready ? Job.Stage.Install : u.Beside ? Job.Stage.Verify : Job.Stage.Download, u.Have, u.Total);
        shownStage = job.Now; stageStart = 0; meter.Reset();
        // Прежнюю метку остановки стирает BuildUpdate.Run после своих отказов (судья 2026-11-18, круг 2, находка 5).
        Form.Busy = true;
        tick.Start();
        Refresh();
        string press = Ui.T(update ? "btn.update" : "btn.install");
        // Вопрос с настоящим размером скачивания — из фона в окно, после сверки файлов прежних сборок (обновление по списку файлов). [NOT-TESTED]
        Func<long, int, bool, bool> confirm = null;
        // И первая установка по списку: её экран не знает размера («лаунчер назовёт после проверки файлов»), вопрос с настоящим размером — после
        // сверки (судья 2026-11-21, круг 5, дефект 1: 13,7 ГБ качались без слова после строки «Нужно скачать 0,1 МБ»).
        if (u.ByManifest)
            confirm = (bytes, files, whole) =>
            {
                bool yes = false;
                try
                {
                    Form.Invoke((Action)(() =>
                    {
                        string drive = Path.GetPathRoot(u.GameDir).TrimEnd('\\'), installed = game?.BuildVersion ?? Bundle.PackVersion(here);
                        string free = u.FreeKnown ? Ui.F("box.update.free", drive, Ui.Size(u.Free)) : "";
                        // whole — список файлов негоден и дело идёт частями архива: вопрос о скачивании всего архива с причиной первой.
                        string text = update
                            ? (whole ? Ui.F("box.update.ask.whole", u.Version, Ui.Size(bytes), installed, free)
                                     : Ui.F("box.delta.ask", u.Version, Ui.Size(bytes), files, installed, free))
                            : (whole ? Ui.F("box.install.ask.whole", u.Version, Ui.Size(bytes), free)
                                     : Ui.F("box.delta.install", u.Version, Ui.Size(bytes), files, free));
                        yes = MessageBox.Show(Form, text, title,
                                              MessageBoxButtons.YesNo, MessageBoxIcon.Question, MessageBoxDefaultButton.Button1) == DialogResult.Yes;
                    }));
                }
                catch (Exception ex) { MetalWindow.Log("вопрос об обновлении не показан: " + ex.Message); }
                return yes;
            };
        ThreadPool.QueueUserWorkItem(_ =>
        {
            string error;
            Action<bool> stoppable = can => { try { Form.Invoke((Action)(() => cancel.Enabled = can)); } catch (Exception) { } };
            try { error = u.Run(job, () => stop, stoppable, press, confirm); }
            catch (Exception ex) { MetalWindow.Log("установка упала: " + ex); error = Ui.F("u.failed", ex.Message); }
            OnUi(() => Finished(u, update, error));
        });
    }

    void Finished(BuildUpdate u, bool update, string error)
    {
        Children.ReleaseUpdate();
        job = null; Form.Busy = false; tick.Stop(); cancel.Enabled = true;
        if (error == BuildUpdate.DECLINED) { Refresh(); return; }
        if (u.Stop != null)
        {
            // Остановка — не ошибка: окно показывает, сколько скачано, и «Продолжить скачивание»; причина — в метке папки частей (следующий запуск её прочитает).
            WriteStopMark(u, u.Stop);
            Refresh();
            // Обновление поставленной сборки: экран остаётся «сборка стоит», причину остановки игрок читает в сообщении; следующее «Обновить сборку» докачает.
            // Первая установка по списку файлов — так же: у неё нет папки частей, метки остановки и экрана «Продолжить скачивание», и окно молча
            // возвращалось к началу (судья, круг 5, дефект 2); следующее «Установить сборку» докачивает .staging\.dl по Range.
            if (update || u.ByManifest) MessageBox.Show(Form, error, Ui.T(update ? "box.update" : "box.install"), MessageBoxButtons.OK, MessageBoxIcon.Information);
            return;
        }
        if (error == null)
        {
            // Сборка из архива встала в папку игры со своим лаунчером: дальше работает он (его ярлык на рабочем столе ставит install.ps1).
            if (u.Local == null && File.Exists(u.NewLauncher)
                && KrinikConanLauncher.Start(u.NewLauncher, update ? KrinikConanLauncher.OLD_BUNDLE_ARG + " \"" + Path.GetFullPath(here).TrimEnd('\\') + "\"" : ""))
            { Form.Close(); return; }
            Refresh();
            if (u.Local == null) MessageBox.Show(Form, Ui.F("box.update.placed", u.Version, u.BundleDir), Ui.T(update ? "box.update" : "box.install"), MessageBoxButtons.OK, MessageBoxIcon.Information);
            return;
        }
        // Ошибка с недокачанными частями: метка «error», окно за сообщением говорит об ошибке, а не об обрыве связи (судья 2026-11-18, находка 3). Отказ до
        // начала дела (u.Started ложно) папку частей не трогает.
        if (u.Started) WriteStopMark(u, "error");
        Refresh();
        MessageBox.Show(Form, error, Ui.T(update ? "box.update" : "box.install"), MessageBoxButtons.OK, MessageBoxIcon.Information);
    }

    void UpdateLauncher()
    {
        if (job != null || feed?.Launcher == null) return;
        if (!KrinikConanLauncher.UpdateAllowed(Form, Ui.T("box.update.launcher"))) return;
        var release = feed.Launcher;
        job = new Job { Version = release.Number.ToString() };
        job.Enter(Job.Stage.Launcher);
        shownStage = job.Now; stageStart = 0; meter.Reset();
        Form.Busy = true;
        tick.Start();
        Refresh();
        ThreadPool.QueueUserWorkItem(_ =>
        {
            string error;
            try { error = SelfUpdate.Run(release, job); }
            catch (Exception ex) { MetalWindow.Log("самообновление упало: " + ex); error = Ui.F("s.crashed", ex.Message); }
            OnUi(() =>
            {
                Children.ReleaseUpdate();
                job = null; Form.Busy = false; tick.Stop();
                if (error == null) { Form.Close(); return; }
                Refresh();
                MessageBox.Show(Form, error, Ui.T("box.update.launcher"), MessageBoxButtons.OK, MessageBoxIcon.Warning);
            });
        });
    }
}

// Кадры для стенда без экрана владельца: KRINIK_LAUNCHER_FRAMES=<папка>;<dpi> — окно раскладывается под этот DPI, стоит за краем экрана и без кнопки
// на панели задач, а лаунчер пишет свою картину (тем же кодом, что на экране) в <папка>\NNN_<экран>_<язык>.png на каждой смене экрана и раз в
// EVERY_S секунд, пока идёт дело. Журнал называет каждый кадр и строки столбика. У игрока этой переменной нет. [NOT-TESTED]
static class Frames
{
    public const double EVERY_S = 2;
    static readonly string[] parts = (Environment.GetEnvironmentVariable("KRINIK_LAUNCHER_FRAMES") ?? "").Split(';');
    public static readonly string Dir = parts[0].Length > 0 ? parts[0] : null;
    public static readonly int Dpi = parts.Length > 1 && int.TryParse(parts[1], out int d) ? d : 0;
    public static bool On => Dir != null;

    // Окна-вопросы Windows (MessageBox, класс #32770) встают по центру монитора, даже когда окно лаунчера стенда стоит за пределами мониторов: вопрос
    // «Удалить сборку?» стенда вышел на экран владельца (2026-11-18 18:44, случай removing). На стенде кадров перехват WH_CBT уводит каждый такой вопрос
    // этого потока туда же, куда и окно, в момент его активации — до первой отрисовки. У игрока перехвата нет. [NOT-TESTED]
    delegate IntPtr CbtProc(int code, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] static extern IntPtr SetWindowsHookEx(int idHook, CbtProc proc, IntPtr module, uint threadId);
    [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr hook, int code, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr hWnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr hWnd, System.Text.StringBuilder name, int max);
    const int WH_CBT = 5, HCBT_ACTIVATE = 5;
    const uint SWP_NOSIZE = 0x0001, SWP_NOZORDER = 0x0004, SWP_NOACTIVATE = 0x0010;
    static CbtProc cbt;   // делегат держится полем: иначе сборщик мусора уберёт его, пока перехват жив
    static IntPtr hook;

    public static void HideBoxes()
    {
        if (!On || hook != IntPtr.Zero) return;
        cbt = (code, wParam, lParam) =>
        {
            if (code == HCBT_ACTIVATE)
            {
                var name = new System.Text.StringBuilder(16);
                GetClassName(wParam, name, name.Capacity);
                if (name.ToString() == "#32770")
                {
                    var p = MetalWindow.OffScreen;
                    SetWindowPos(wParam, IntPtr.Zero, p.X, p.Y, 0, 0, SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
                }
            }
            return CallNextHookEx(hook, code, wParam, lParam);
        };
        hook = SetWindowsHookEx(WH_CBT, cbt, IntPtr.Zero, GetCurrentThreadId());
    }
}

// Шрифты макета 11 едут внутри exe (у игрока нет ни Oswald, ни Inter): статичные начертания из make-res.py, каждое — своё семейство.
// Не загрузились — окно пишет системным шрифтом и открывается всё равно.
static class Fonts
{
    static readonly PrivateFontCollection pack = new PrivateFontCollection();
    public static readonly FontFamily Title = Load("res.oswald_600.ttf", "Krinik Oswald SemiBold", "Segoe UI Semibold");
    public static readonly FontFamily GameName = Load("res.oswald_500.ttf", "Krinik Oswald Medium", "Segoe UI Semibold");
    public static readonly FontFamily Small = Load("res.oswald_400.ttf", "Krinik Oswald", "Segoe UI");
    public static readonly FontFamily Body = Load("res.inter_400.ttf", "Krinik Inter", "Segoe UI");

    static FontFamily Load(string resource, string family, string fallback)
    {
        try
        {
            using (var s = Assembly.GetExecutingAssembly().GetManifestResourceStream(resource))
            {
                if (s != null)
                {
                    var bytes = new byte[s.Length];
                    for (int read = 0, n; read < bytes.Length; read += n)
                        if ((n = s.Read(bytes, read, bytes.Length - read)) <= 0) break;
                    // Память шрифта не освобождается: GDI+ читает из неё при каждом рисовании, пока жив процесс.
                    var mem = Marshal.AllocCoTaskMem(bytes.Length);
                    Marshal.Copy(bytes, 0, mem, bytes.Length);
                    pack.AddMemoryFont(mem, bytes.Length);
                    foreach (var f in pack.Families) if (f.Name == family) return f;
                }
            }
        }
        catch (Exception ex) when (ex is ArgumentException || ex is IOException || ex is ExternalException) { MetalWindow.Log("шрифт " + resource + ": " + ex.Message); }
        MetalWindow.Log("шрифт " + resource + " не найден, пишу " + fallback);
        return new FontFamily(fallback);
    }
}

// Буквы как в браузере макета: строка — контуром GraphicsPath от базовой линии, межбуквенный интервал (letter-spacing) — сдвигом букв,
// тень (text-shadow) — размытой маской, как CSS: гаусс с сигмой в половину радиуса размытия.
static class Lettering
{
    static readonly Graphics Measure = Graphics.FromImage(new Bitmap(1, 1));
    static readonly StringFormat Typo = MakeTypo();

    static StringFormat MakeTypo()
    {
        var f = (StringFormat)StringFormat.GenericTypographic.Clone();
        f.FormatFlags |= StringFormatFlags.MeasureTrailingSpaces | StringFormatFlags.NoWrap;
        return f;
    }

    // Ширина без межбуквенного интервала — по тем же контурам без хинтинга, что и рисуются.
    // Шрифт GDI+ создаётся один раз на (семейство, кегль, начертание), ширина строки запоминается: раскладка окна и списка состояния зовёт Advance
    // сотни раз на каждое обновление, и до 2026-11-20 каждый вызов создавал и уничтожал шрифт (баг 110; Microsoft «Custom painting and drawing» — шрифты
    // кэшировать; KUMM researches/efficient-code §2.2, §2.4). Память ширин ограничена: при WIDTHS_MAX записях она очищается целиком. [NOT-TESTED]
    const int WIDTHS_MAX = 4096;
    static readonly Dictionary<string, Font> fonts = new Dictionary<string, Font>();
    static readonly Dictionary<string, float> widths = new Dictionary<string, float>();

    public static float Advance(string text, FontFamily family, FontStyle style, float px)
    {
        if (string.IsNullOrEmpty(text)) return 0f;
        string face = family.Name + "\u0001" + px.ToString("R") + "\u0001" + (int)style, key = face + "\u0001" + text;
        if (widths.TryGetValue(key, out var known)) return known;
        if (!fonts.TryGetValue(face, out var font)) fonts[face] = font = new Font(family, px, style, GraphicsUnit.Pixel);
        Measure.TextRenderingHint = TextRenderingHint.AntiAlias;
        float w = Measure.MeasureString(text, font, PointF.Empty, Typo).Width;
        if (widths.Count >= WIDTHS_MAX) widths.Clear();
        widths[key] = w;
        return w;
    }

    // Ширина, как её считает CSS: интервал стоит после каждой буквы, и после последней тоже.
    public static float Width(string text, FontFamily family, FontStyle style, float px, float spacing) => Advance(text, family, style, px) + spacing * text.Length;

    // Строка в контур: x — левый край, baseline — базовая линия; GDI+ ставит строку верхом ячейки шрифта, поэтому вверх на её подъём.
    public static void Add(GraphicsPath path, string text, FontFamily family, FontStyle style, float px, float spacing, float x, float baseline)
    {
        float top = baseline - family.GetCellAscent(style) * px / family.GetEmHeight(style);
        if (spacing == 0f) { path.AddString(text, family, (int)style, px, new PointF(x, top), Typo); return; }
        for (int i = 0; i < text.Length; i++)
            if (!char.IsWhiteSpace(text[i]))
                path.AddString(text[i].ToString(), family, (int)style, px, new PointF(x + Advance(text.Substring(0, i), family, style, px) + spacing * i, top), Typo);
    }

    // Подчёркивание ссылки, как у Chrome: полоска под базовой линией с разрывами там, где её пересекают хвосты букв (у, р, g).
    public static void Underline(GraphicsPath glyphs, GraphicsPath into, float x0, float x1, float y, float thickness)
    {
        float gap = Math.Max(1f, thickness);
        var cuts = new List<(float a, float b)>();
        using (var region = new Region(glyphs))
        using (var m = new Matrix())
        {
            region.Intersect(new RectangleF(x0, y - gap, x1 - x0, thickness + 2 * gap));
            foreach (var r in region.GetRegionScans(m)) cuts.Add((r.Left - gap, r.Right + gap));
        }
        cuts.Sort((p, q) => p.a.CompareTo(q.a));
        float x = x0;
        foreach (var c in cuts)
        {
            if (c.a > x) into.AddRectangle(new RectangleF(x, y, c.a - x, thickness));
            x = Math.Max(x, c.b);
        }
        if (x < x1) into.AddRectangle(new RectangleF(x, y, x1 - x, thickness));
    }

    // Тень CSS (text-shadow / drop-shadow): форма заливается цветом, сдвигается и размывается; три прохода «коробкой» дают почти гаусс.
    public static void Shadow(Graphics g, GraphicsPath shape, float dx, float dy, float blur, Color color)
    {
        var b = shape.GetBounds();
        if (b.Width <= 0 || b.Height <= 0) return;
        int r = Math.Max(1, (int)Math.Round(blur / 2f)), m = 3 * r + 2 + (int)Math.Ceiling(Math.Max(Math.Abs(dx), Math.Abs(dy)));
        int x0 = (int)Math.Floor(b.Left) - m, y0 = (int)Math.Floor(b.Top) - m;
        int w = (int)Math.Ceiling(b.Right) + m - x0, h = (int)Math.Ceiling(b.Bottom) + m - y0;
        using (var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb))
        {
            using (var mg = Graphics.FromImage(bmp))
            {
                mg.SmoothingMode = SmoothingMode.AntiAlias;
                mg.TranslateTransform(dx - x0, dy - y0);
                mg.FillPath(Brushes.Black, shape);
            }
            var data = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
            try
            {
                int stride = data.Stride;
                var px = new byte[stride * h];
                Marshal.Copy(data.Scan0, px, 0, px.Length);
                var a = new int[w * h];
                for (int y = 0; y < h; y++)
                    for (int x = 0; x < w; x++) a[y * w + x] = px[y * stride + x * 4 + 3];
                var tmp = new int[Math.Max(w, h)];
                for (int pass = 0; pass < 3; pass++) { Box(a, w, h, r, tmp, true); Box(a, w, h, r, tmp, false); }
                for (int y = 0; y < h; y++)
                    for (int x = 0; x < w; x++)
                    {
                        int i = y * stride + x * 4;
                        px[i] = color.B; px[i + 1] = color.G; px[i + 2] = color.R;
                        px[i + 3] = (byte)Math.Min(255, a[y * w + x] * color.A / 255);
                    }
                Marshal.Copy(px, 0, data.Scan0, px.Length);
            }
            finally { bmp.UnlockBits(data); }
            var oldMode = g.InterpolationMode;
            g.InterpolationMode = InterpolationMode.NearestNeighbor; // один к одному, без пересчёта
            g.DrawImage(bmp, new Rectangle(x0, y0, w, h), 0, 0, w, h, GraphicsUnit.Pixel);
            g.InterpolationMode = oldMode;
        }
    }

    // Скользящее среднее шириной 2r+1 по строкам (rows) или столбцам маски; за краем маски — пусто.
    static void Box(int[] a, int w, int h, int r, int[] tmp, bool rows)
    {
        int d = 2 * r + 1, lines = rows ? h : w, len = rows ? w : h, step = rows ? 1 : w;
        for (int line = 0; line < lines; line++)
        {
            int start = rows ? line * w : line, sum = 0;
            for (int k = 0; k <= r && k < len; k++) sum += a[start + k * step];
            for (int k = 0; k < len; k++)
            {
                tmp[k] = (sum + r) / d;
                int add = k + r + 1, sub = k - r;
                if (add < len) sum += a[start + add * step];
                if (sub >= 0) sum -= a[start + sub * step];
            }
            for (int k = 0; k < len; k++) a[start + k * step] = tmp[k];
        }
    }

    // Перенос по ширине: рвём после пробела или обратной косой черты пути; слово длиннее строки остаётся целым.
    public static List<string> Wrap(string text, Func<string, float> width, float max)
    {
        var lines = new List<string>();
        // «\n» в тексте — свой перенос: каждое предложение с новой строки (строка «Игра не найдена.», KUMM plans/56). [NOT-TESTED]
        foreach (var paragraph in text.Split('\n'))
        {
            string rest = paragraph;
            while (rest.Length > 0 && width(rest) > max)
            {
                int cut = -1;
                for (int i = rest.Length - 1; i > 0; i--)
                    if ((rest[i - 1] == ' ' || rest[i - 1] == '\\') && width(rest.Substring(0, i).TrimEnd()) <= max) { cut = i; break; }
                if (cut < 0) break;
                lines.Add(rest.Substring(0, cut).TrimEnd());
                rest = rest.Substring(cut);
            }
            lines.Add(rest);
        }
        return lines;
    }
}

// Металл Конана: медь и золото букв логотипа (art/logos/conan-exiles-enhanced-logo-3x.webp) и тёмное железо его таблички.
static class Metal
{
    public static Color Html(string hex) => ColorTranslator.FromHtml(hex);

    // Курсор «рука» — СИСТЕМНЫЙ (IDC_HAND). Cursors.Hand в .NET Framework — свой курсор WinForms фиксированного размера 32×32, а не системный:
    // при масштабе 300 % стрелка Windows крупная, рука мелкая, и на кнопке курсор менял размер (владелец 2026-11-18 16:22 «курсор меняет размер при
    // наведении на кнопки»). Системная рука масштабируется вместе со стрелкой и следует размеру указателя из настроек Windows. [NOT-TESTED]
    [System.Runtime.InteropServices.DllImport("user32.dll")] static extern IntPtr LoadCursor(IntPtr hInstance, IntPtr lpCursorName);
    const int IDC_HAND = 32649;
    static Cursor hand;
    public static Cursor Hand
    {
        get
        {
            if (hand != null) return hand;
            IntPtr h = LoadCursor(IntPtr.Zero, (IntPtr)IDC_HAND);
            hand = h != IntPtr.Zero ? new Cursor(h) : Cursors.Hand;   // нет системной руки — запасной курсор WinForms
            return hand;
        }
    }

    // Окантовка кнопки сверху вниз: свет падает сверху, снизу — отражённый отблеск.
    public static readonly ColorBlend Rim = Blend(("#f7e2a6", 0f), ("#d9a352", .3f), ("#a1622a", .6f), ("#5e3411", .86f), ("#b47a3c", 1f));
    public static readonly ColorBlend RimOff = Blend(("#a29b92", 0f), ("#7a746c", .45f), ("#4a4642", .86f), ("#6e6862", 1f));
    // Золотое лицо «Играть» (макет 11: #ffe7a8 → #f2b85a → #c97a2c), под мышью — светлее, нажатая — темнее.
    public static readonly ColorBlend GoldFace = Blend(("#ffe7a8", 0f), ("#f2b85a", .48f), ("#c97a2c", 1f));
    public static readonly ColorBlend GoldHover = Blend(("#fff1c6", 0f), ("#f8c870", .48f), ("#d98d3a", 1f));
    public static readonly ColorBlend GoldDown = Blend(("#e8c47e", 0f), ("#d79a46", .48f), ("#a8642a", 1f));

    public static ColorBlend Blend(params (string color, float pos)[] stops)
    {
        var b = new ColorBlend(stops.Length);
        for (int i = 0; i < stops.Length; i++) { b.Colors[i] = Html(stops[i].color); b.Positions[i] = stops[i].pos; }
        return b;
    }

    // Масштаб экрана для части окна: его знает окно (DPI своего монитора), без окна — DPI самого элемента.
    public static float Zoom(Control c) => c.FindForm() is MetalWindow w ? w.Zoom : c.DeviceDpi / 96f;

    // Кусок готовой картинки 1:1 в пикселях: приёмник и источник заданы пикселями (DrawImageUnscaled мерил бы картинку дюймами её DPI), без сглаживания и
    // сдвига на полпикселя — копия пиксель в пиксель. [NOT-TESTED]
    public static void Blit(Graphics g, Bitmap image, Rectangle part)
    {
        var im = g.InterpolationMode;
        var po = g.PixelOffsetMode;
        g.InterpolationMode = InterpolationMode.NearestNeighbor;
        g.PixelOffsetMode = PixelOffsetMode.Half;
        g.DrawImage(image, part, part, GraphicsUnit.Pixel);
        g.InterpolationMode = im;
        g.PixelOffsetMode = po;
    }

    // Прямоугольник со срезанными углами — как табличка «ENHANCED» на логотипе.
    public static GraphicsPath Chamfer(RectangleF r, float c)
    {
        var p = new GraphicsPath();
        p.AddPolygon(new[]
        {
            new PointF(r.Left + c, r.Top), new PointF(r.Right - c, r.Top), new PointF(r.Right, r.Top + c), new PointF(r.Right, r.Bottom - c),
            new PointF(r.Right - c, r.Bottom), new PointF(r.Left + c, r.Bottom), new PointF(r.Left, r.Bottom - c), new PointF(r.Left, r.Top + c)
        });
        return p;
    }

    // Металлическая табличка: окантовка медью и золотом, лицо — тёмное железо. scale — масштаб экрана (1 = 96 dpi).
    public static RectangleF Plaque(Graphics g, Rectangle bounds, float scale, bool enabled, Color faceTop, Color faceBottom)
    {
        var face = new ColorBlend(2) { Colors = new[] { faceTop, faceBottom }, Positions = new[] { 0f, 1f } };
        return Plaque(g, bounds, scale, enabled, face, Color.FromArgb(enabled ? 70 : 30, 255, 232, 180));
    }

    // То же со своим кантом: у раскрытого выбора языка кант золотой, как лицо «Играть» (.lang.open .pl макета).
    public static RectangleF Plaque(Graphics g, Rectangle bounds, float scale, ColorBlend rim, Color faceTop, Color faceBottom)
    {
        var face = new ColorBlend(2) { Colors = new[] { faceTop, faceBottom }, Positions = new[] { 0f, 1f } };
        return Plaque(g, bounds, scale, rim, face, Color.FromArgb(70, 255, 232, 180));
    }

    // То же с лицом из нескольких цветов и своим бликом по верхнему краю (золотая «Играть»: блик #fff3c9 во всю силу).
    public static RectangleF Plaque(Graphics g, Rectangle bounds, float scale, bool enabled, ColorBlend faceBlend, Color sheen) =>
        Plaque(g, bounds, scale, enabled ? Rim : RimOff, faceBlend, sheen);

    static RectangleF Plaque(Graphics g, Rectangle bounds, float scale, ColorBlend rimBlend, ColorBlend faceBlend, Color sheen)
    {
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        var outer = new RectangleF(bounds.X, bounds.Y, bounds.Width, bounds.Height);
        float rim = Math.Max(2f, 2.5f * scale), cut = Math.Max(3f, 6f * scale);
        using (var path = Chamfer(outer, cut))
        using (var brush = new LinearGradientBrush(RectangleF.Inflate(outer, 0, 1), Color.Black, Color.Black, 90f))
        {
            brush.InterpolationColors = rimBlend;
            g.FillPath(brush, path);
        }
        var face = RectangleF.Inflate(outer, -rim, -rim);
        using (var path = Chamfer(face, Math.Max(1f, cut - rim * 0.6f)))
        using (var brush = new LinearGradientBrush(RectangleF.Inflate(face, 0, 1), Color.Black, Color.Black, 90f))
        {
            brush.InterpolationColors = faceBlend;
            g.FillPath(brush, path);
        }
        // Тонкий блик по верхнему краю лица — металл, а не плоская заливка.
        using (var pen = new Pen(sheen, Math.Max(1f, scale)))
            g.DrawLine(pen, face.Left + cut * 0.6f, face.Top + pen.Width / 2, face.Right - cut * 0.6f, face.Top + pen.Width / 2);
        return face;
    }
}

// Надпись таблички «Отзыв»: буквы с тёмной обводкой и тенью — читается на тёмном железе и на любом куске картины.
class OutlinedLabel : Label
{
    static readonly Graphics Measure = Graphics.FromHwnd(IntPtr.Zero);
    static readonly StringFormat Format = new StringFormat(StringFormat.GenericTypographic) { Trimming = StringTrimming.None };

    public OutlinedLabel()
    {
        SetStyle(ControlStyles.SupportsTransparentBackColor | ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint |
                 ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
        BackColor = Color.Transparent;
    }

    // Толщина обводки — от размера букв: у мелкого текста тоньше, у заголовка толще.
    float Outline(float dpi) => Math.Max(1.6f, Font.SizeInPoints * dpi / 72f * 0.11f);
    int Pad(float dpi) => (int)Math.Ceiling(Outline(dpi) + 2f * dpi / 96f);

    public override Size GetPreferredSize(Size proposed)
    {
        float dpi = Measure.DpiY;
        int pad = Pad(dpi);
        int maxW = MaximumSize.Width > 0 ? MaximumSize.Width - 2 * pad : 100000;
        var size = Measure.MeasureString(Text, Font, maxW, Format);
        return new Size((int)Math.Ceiling(size.Width) + 2 * pad + 1, (int)Math.Ceiling(size.Height) + 2 * pad);
    }

    // Готовая надпись (буквы, обводка, тень) — картинка под ключом её входов: текст, шрифт, цвет, размер, DPI; перерисовка только копирует её. До кэша
    // каждая перерисовка строила контур букв и обводила его широким пером заново, ≈ 9 мс на строку при 300 % (баг 110, кейс perf-report стенда,
    // 2026-11-22). Картинка рисуется тем же кодом, что и прямо на экране; промежуточный слой с премультиплицированной альфой даёт отличие края букв не
    // больше 1/255 (сверка кадров до и после, судья 2026-11-22, круг 1, находка 5). [TESTED: 2026-11-22 · perf-report FB0–FB2, кадры · KUMM testcases/reports/2026-11-22_conan-launcher-feedback-window.md]
    Bitmap face;
    string faceKey;

    protected override void OnPaint(PaintEventArgs e)
    {
        using (MetalWindow.Perf("OutlinedLabel.OnPaint"))
        {
            var inv = System.Globalization.CultureInfo.InvariantCulture;
            float dpi = e.Graphics.DpiY;
            string key = string.Join("|", Text, Font.Name, Font.Size.ToString(inv), (int)Font.Style, (int)Font.Unit, ForeColor.ToArgb(), Width, Height, dpi.ToString(inv));
            if (face == null || key != faceKey)
            {
                face?.Dispose();
                face = new Bitmap(Math.Max(1, Width), Math.Max(1, Height), PixelFormat.Format32bppPArgb);
                using (var g = Graphics.FromImage(face)) DrawText(g, dpi);
                faceKey = key;
            }
            Metal.Blit(e.Graphics, face, new Rectangle(Point.Empty, face.Size));
        }
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing) { face?.Dispose(); face = null; }
        base.Dispose(disposing);
    }

    void DrawText(Graphics g, float dpi)
    {
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        float outline = Outline(dpi), scale = dpi / 96f;
        int pad = Pad(dpi);
        var layout = new RectangleF(pad, pad, Width - 2 * pad + 1, Height - 2 * pad + 1);
        using (var path = new GraphicsPath())
        {
            path.AddString(Text, Font.FontFamily, (int)Font.Style, Font.SizeInPoints * dpi / 72f, layout, Format);
            using (var shadow = (GraphicsPath)path.Clone())
            using (var m = new Matrix())
            {
                m.Translate(1.2f * scale, 1.8f * scale);
                shadow.Transform(m);
                using (var pen = new Pen(Color.FromArgb(120, 0, 0, 0), outline * 2.4f) { LineJoin = LineJoin.Round })
                    g.DrawPath(pen, shadow);
            }
            using (var pen = new Pen(Color.FromArgb(235, 16, 9, 3), outline * 2f) { LineJoin = LineJoin.Round })
                g.DrawPath(pen, path);
            using (var fill = new SolidBrush(ForeColor)) g.FillPath(fill, path);
        }
    }
}

// Табличка раздела «Отзыв»: тёмное железо в медной окантовке, как кнопки; видна, только пока раздел открыт.
sealed class ReportPlaque : FlowLayoutPanel
{
    public ReportPlaque()
    {
        SetStyle(ControlStyles.SupportsTransparentBackColor | ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint |
                 ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
        BackColor = Color.Transparent;
        FlowDirection = FlowDirection.TopDown;
        WrapContents = false;
        AutoSize = true;
        AutoSizeMode = AutoSizeMode.GrowAndShrink; // по умолчанию только растёт: ширина до переноса строк осталась бы и заехала под столбик
    }

    // Железо таблички — картинка под ключом размера и масштаба, рисуется один раз и дальше только копируется своим куском. Надписи таблички прозрачны, и
    // Windows Forms рисует фон родителя под каждой: до кэша табличка рисовалась восемь раз на одно открытие (сама, шесть надписей, кнопка), ≈ 23 мс при
    // 300 % (баг 110, кейс perf-report стенда, 2026-11-22). Под табличкой остаётся картина окна (base — прозрачный фон). [NOT-TESTED]
    Bitmap face;
    string faceKey;

    protected override void OnPaintBackground(PaintEventArgs e)
    {
        using (MetalWindow.Perf("ReportPlaque.Background"))
        {
            base.OnPaintBackground(e);
            float zoom = Metal.Zoom(this);
            string key = Width + "x" + Height + "|" + zoom.ToString(System.Globalization.CultureInfo.InvariantCulture);
            if (face == null || key != faceKey)
            {
                face?.Dispose();
                face = new Bitmap(Math.Max(1, Width), Math.Max(1, Height), PixelFormat.Format32bppPArgb);
                using (var g = Graphics.FromImage(face))
                    Metal.Plaque(g, new Rectangle(0, 0, Width, Height), zoom, true, Color.FromArgb(238, 0x2a, 0x21, 0x18), Color.FromArgb(238, 0x12, 0x0e, 0x0a));
                faceKey = key;
            }
            // ClipRectangle — в координатах таблички и тогда, когда фон рисуется под надписью (Windows Forms сдвигает Graphics на её место).
            var part = Rectangle.Intersect(e.ClipRectangle, new Rectangle(Point.Empty, face.Size));
            if (part.Width > 0 && part.Height > 0) Metal.Blit(e.Graphics, face, part);
        }
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing) { face?.Dispose(); face = null; }
        base.Dispose(disposing);
    }
}

// Кнопка из металла: рисуется целиком сама, фон под срезанными углами — картина окна.
// Gold — золотое лицо и тёмные буквы с интервалом, как «Играть» макета 11; без игры она гаснет, как остальные.
sealed class MetalButton : Button
{
    // Georgia (hhea): подъём и высота строки в долях кегля — CSS ставит строку по центру кнопки по ним.
    const float GEORGIA_ASC = .917f, GEORGIA_LINE = 1.136f, GOLD_SPACING = .06f;
    bool hover, down;

    public bool Gold { get; set; }
    // Межбуквенный интервал золотой надписи в долях кегля: .06em у главной кнопки столбика (.col > .pl.gold макета); у кнопок выбора копии и плашки
    // обновлений интервала в макете нет (0).
    public float Spacing { get; set; } = GOLD_SPACING;

    public MetalButton()
    {
        SetStyle(ControlStyles.SupportsTransparentBackColor | ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint |
                 ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
        // ButtonBase ставит себе Opaque: фон рисует сам OnPaint, а наш OnPaint его не рисует — под срезанными углами на экране оставалась пустота
        // двойного буфера, чёрные треугольники (владелец 2026-11-17 22:06 «уголки какие-то темные у них есть, видишь?»; снимок KRINIK_LAUNCHER_SNAPSHOT
        // рисует кнопку поверх готовой картины через DrawToBitmap и дефект прятал — виден только живой захват окна, PrintWindow). Без Opaque прозрачный
        // фон — картина окна под кнопкой. [NOT-TESTED]
        SetStyle(ControlStyles.Opaque, false);
        FlatStyle = FlatStyle.Flat;
        FlatAppearance.BorderSize = 0;
        UseVisualStyleBackColor = false;
        BackColor = Color.Transparent;
    }

    protected override void OnMouseEnter(EventArgs e) { hover = true; Invalidate(); base.OnMouseEnter(e); }
    protected override void OnMouseLeave(EventArgs e) { hover = down = false; Invalidate(); base.OnMouseLeave(e); }
    protected override void OnMouseDown(MouseEventArgs e) { if (e.Button == MouseButtons.Left) { down = true; Invalidate(); } base.OnMouseDown(e); }
    protected override void OnMouseUp(MouseEventArgs e) { down = false; Invalidate(); base.OnMouseUp(e); }
    protected override void OnEnabledChanged(EventArgs e) { Invalidate(); base.OnEnabledChanged(e); }

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        float scale = Metal.Zoom(this);
        RectangleF face;
        // Погасшая золотая (.pl.gold.off макета: под выбором копии, пока лента читается) — то же золото на 45 % непрозрачности: место главной кнопки
        // не пустеет и не становится серой кнопкой (`[OWNER]` 2026-11-03 20:54 — главная CTA всегда золотая). [NOT-TESTED]
        if (Gold && !Enabled && Width > 0 && Height > 0)
        {
            using (var layer = new Bitmap(Width, Height, PixelFormat.Format32bppPArgb))
            {
                using (var lg = Graphics.FromImage(layer))
                {
                    var f = Metal.Plaque(lg, new Rectangle(0, 0, Width, Height), scale, true, Metal.GoldFace, Metal.Html("#fff3c9"));
                    PaintGoldText(lg, f, scale);
                }
                using (var ia = new ImageAttributes())
                {
                    ia.SetColorMatrix(new ColorMatrix { Matrix33 = .45f });
                    g.DrawImage(layer, new Rectangle(0, 0, Width, Height), 0, 0, Width, Height, GraphicsUnit.Pixel, ia);
                }
            }
            return;
        }
        if (Gold && Enabled)
        {
            face = Metal.Plaque(g, new Rectangle(0, 0, Width, Height), scale, true,
                                down ? Metal.GoldDown : hover ? Metal.GoldHover : Metal.GoldFace, Metal.Html("#fff3c9"));
            PaintGoldText(g, face, scale);
        }
        else
        {
            Color top, bottom;
            if (!Enabled) { top = Metal.Html("#2e2b28"); bottom = Metal.Html("#1b1a19"); }
            else if (down) { top = Metal.Html("#120d08"); bottom = Metal.Html("#33271b"); }
            else if (hover) { top = Metal.Html("#56412b"); bottom = Metal.Html("#231910"); }
            else { top = Metal.Html("#3b2e21"); bottom = Metal.Html("#161009"); }
            face = Metal.Plaque(g, new Rectangle(0, 0, Width, Height), scale, Enabled, top, bottom);
            var text = Rectangle.Round(face);
            if (down) text.Offset(0, 1);
            const TextFormatFlags flags = TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine;
            if (Enabled)
            {
                var shadow = text; shadow.Offset(Math.Max(1, (int)scale), Math.Max(1, (int)scale));
                TextRenderer.DrawText(g, Text, Font, shadow, Color.Black, flags);
            }
            TextRenderer.DrawText(g, Text, Font, text, Enabled ? Metal.Html("#f6e4bc") : Metal.Html("#8a847b"), flags);
        }
        if (Focused && ShowFocusCues)
            using (var pen = new Pen(Color.FromArgb(150, Gold && Enabled ? Metal.Html("#2a1606") : Metal.Html("#f6e4bc")), 1f) { DashStyle = DashStyle.Dot })
                g.DrawRectangle(pen, Rectangle.Inflate(Rectangle.Round(face), -(int)(3 * scale), -(int)(3 * scale)));
    }

    // Буквы «Играть»: тёмные (#2a1606) с интервалом .06em и светлым отблеском на пиксель ниже (text-shadow 0 1px 0 rgba(255,244,214,.7)).
    void PaintGoldText(Graphics g, RectangleF face, float scale)
    {
        float px = Font.Unit == GraphicsUnit.Pixel ? Font.Size : Font.SizeInPoints * DeviceDpi / 72f, spacing = Spacing * px;
        float width = Lettering.Width(Text, Font.FontFamily, Font.Style, px, spacing);
        // Надпись не шире лица кнопки (поля по 6 логических px): «Продолжить скачивание» кеглем 22 и «Установить сборку» выбора копии вылезали за край
        // (кадры стенда 2026-11-18 15:5x); длинная английская надпись — так же. Кегль и интервал уменьшаются вместе. [NOT-TESTED]
        float room = face.Width - 12f * scale;
        if (width > room && width > 0) { float k = room / width; px *= k; spacing *= k; width = room; }
        float baseline = face.Top + face.Height / 2 - GEORGIA_LINE * px / 2 + GEORGIA_ASC * px + (down ? 1 : 0);
        using (var path = new GraphicsPath())
        {
            Lettering.Add(path, Text, Font.FontFamily, Font.Style, px, spacing, face.Left + (face.Width - width) / 2, baseline);
            g.SmoothingMode = SmoothingMode.AntiAlias;
            using (var glint = (GraphicsPath)path.Clone())
            using (var m = new Matrix())
            using (var brush = new SolidBrush(Color.FromArgb(179, 255, 244, 214)))
            {
                m.Translate(0, scale);
                glint.Transform(m);
                g.FillPath(brush, glint);
            }
            using (var brush = new SolidBrush(Metal.Html("#2a1606"))) g.FillPath(brush, path);
        }
    }
}

// «Свернуть» и «Закрыть» вместо кнопок Windows: та же металлическая табличка, знак — золотом (макет 11: значок 14 px, штрих 2.2 px).
sealed class CaptionButton : Control
{
    readonly bool isClose;
    bool hover, down;

    public CaptionButton(bool isClose, string tip)
    {
        this.isClose = isClose;
        SetStyle(ControlStyles.SupportsTransparentBackColor | ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint |
                 ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
        SetStyle(ControlStyles.Selectable, false);
        BackColor = Color.Transparent;
        Cursor = Metal.Hand;
        AccessibleName = tip;
        AccessibleRole = AccessibleRole.PushButton;
    }

    protected override void OnMouseEnter(EventArgs e) { hover = true; Invalidate(); base.OnMouseEnter(e); }
    protected override void OnMouseLeave(EventArgs e) { hover = down = false; Invalidate(); base.OnMouseLeave(e); }
    protected override void OnMouseDown(MouseEventArgs e) { if (e.Button == MouseButtons.Left) { down = true; Invalidate(); } base.OnMouseDown(e); }
    protected override void OnMouseUp(MouseEventArgs e) { down = false; Invalidate(); base.OnMouseUp(e); }

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        float scale = Metal.Zoom(this);
        Color top, bottom;
        if (down) { top = Metal.Html("#120d08"); bottom = Metal.Html("#33271b"); }
        else if (hover && isClose) { top = Metal.Html("#9a2a17"); bottom = Metal.Html("#430d06"); }
        else if (hover) { top = Metal.Html("#56412b"); bottom = Metal.Html("#231910"); }
        else { top = Metal.Html("#3b2e21"); bottom = Metal.Html("#161009"); }
        var face = Metal.Plaque(g, new Rectangle(0, 0, Width, Height), scale, true, top, bottom);

        // Значок макета в квадрате 14 px по центру: крест (2,2)–(12,12), черта (1.5,10)–(12.5,10); золото сверху вниз.
        float cx = face.Left + face.Width / 2, cy = face.Top + face.Height / 2, u = scale;
        using (var glyph = new LinearGradientBrush(new RectangleF(cx - 7 * u, cy - 6 * u - 1, 14 * u, 12 * u + 2), Metal.Html("#fbe9b6"), Metal.Html("#c98a44"), 90f))
        using (var pen = new Pen(glyph, Math.Max(1.5f, 2.2f * scale)) { StartCap = LineCap.Round, EndCap = LineCap.Round })
        {
            if (isClose)
            {
                g.DrawLine(pen, cx - 5 * u, cy - 5 * u, cx + 5 * u, cy + 5 * u);
                g.DrawLine(pen, cx - 5 * u, cy + 5 * u, cx + 5 * u, cy - 5 * u);
            }
            else g.DrawLine(pen, cx - 5.5f * u, cy + 3 * u, cx + 5.5f * u, cy + 3 * u);
        }
    }
}

// Окно без рамки Windows по макету 11: картина, затемнение, логотипы, заголовок, путь к игре и ссылки рисуются один раз в картинку
// размера окна (кэш) и пересобираются при смене размера или масштаба; кнопки и табличка «Отзыв» — свои элементы поверх, они берут фон
// из того же кэша. Кайма — полосы сырого металла res/frame_*.png; где у её внешней кромки скол (пиксели прозрачнее половины),
// окно там вырезано (SetWindowRgn) — виден рабочий стол.
sealed class MetalWindow : Form
{
    // Числа макета 11 — логические пиксели окна 960×540 (CSS-пиксели макета), на экране умножаются на масштаб Windows.
    const float WIN_W = 960f, WIN_H = 540f, FRAME = 3f;                                       // кайма play 7 — 3 px
    const float CAPS_TOP = 18f, CAPS_RIGHT = 20f, CAPS_GAP = 6f, CAP_W = 38f, CAP_H = 28f;     // .caps
    const float TOP = 24f, LEFT = 30f, LOGO_GAME_H = 54f, LOGO_PACK_H = 50f, TOP_GAP = 18f;    // .top: логотипы и заголовок в ряд, по центру высоты
    const float TITLE_PX = 25f, TITLE_LINE = 1.1f, TITLE_SPACING = .02f, TITLE_INDENT = 6f;   // h1: 600 25px/1.1 Oswald, .02em, margin-left 6
    const float GAME_PX = 17f, GAME_SPACING = .1f, GAME_GAP = 3f;                             // h2: 500 17px Oswald, .1em, заглавными, margin-top 3
    // small: 400 8px, right 100% + 5, bottom 3. Кегль — не 8, а 10: в CSS стоит 8px, но Chrome нарисовал «для» крупнее, и утверждён этот кадр
    // (31_launcher_frame_1_and_2_thinner/variant_11_play7.webp: ширина «для» — 14.4 логических px; так пишет Oswald 10 px, 8 px дают 11.3).
    const float DLYA_PX = 10f, DLYA_SPACING = .06f, DLYA_GAP = 5f, DLYA_RAISE = 3f;
    const float COL_RIGHT = 30f, COL_BOTTOM = 28f, COL_W = 270f, COL_GAP = 9f;                // .col
    const float BUTTON_H = 44f, BUTTON_FONT = 18.7f, PLAY_H = 70f, PLAY_FONT = 28f;           // .pl 44 / .play 70; Georgia 700 18.7 / 28
    public const float INSTALL_FONT = 22f;                                                     // золотая «Установить сборку» — 22 px (макет state=fresh)
    const float PATH_PX = 12f, PATH_GAP = 10f;                                                 // .status: 12px Inter, margin-top 10
    const float LINKS_LEFT = 30f, LINKS_BOTTOM = 26f, LINK_PX = 13f, LINK_LINE = 1.7f, UNDERLINE_OFFSET = 2f; // .links: 13px/1.7 Inter
    const float ASIDE_GAP = 24f, ASIDE_ABOVE_LINKS = 14f, ASIDE_BELOW_TITLE = 16f;             // табличка «Отзыв» — её в макете нет
    // Версии под логотипами — как в главном меню игры (_config/devkit/kit-conanui-edit.py): каждая под СВОИМ логотипом, по центру его сплошной
    // части (альфа ≥ 64 — мягкая тень логотипа в счёт не идёт), на одном отступе от её низа, цветом строки меню. `[OWNER]` 2026-11-02 18:47
    // «нужно, чтобы в лаунчере под логотипами были написаны версия игры и версия сборки, прям как в глвном меню мы сделали».
    // Шрифт — засечный с ровными цифрами, как цифры версий в меню игры: Cambria Bold (в Windows с Vista). У Georgia цифры старого стиля
    // («0.9.0» с выносными) — с меню не сходится (снимок 2026-11-02 18:57 +03:00); она — только запасная.
    const float VER_PX = 13f, VER_SPACING = .04f, VER_GAP = 2f;                               // [AI] кегль 13 px — чуть крупнее строки пути
    // «Что нового» под строкой версии (KUMM plan 54): кнопка столбика в малом — металл, Georgia bold; ширина — по тексту с полями.
    const float NOTES_H = 24f, NOTES_FONT = 12.5f, NOTES_PAD = 10f, NOTES_GAP = 5f;           // [AI] размеры — по строке версии над ней
    const float PLATE_GAP = 16f;                                                               // плашка обновлений — под шапкой, слева
    // Версия лаунчера — мелкой строкой «Лаунчер: 1.0.0» справа вверху, под кнопками «Свернуть» и «Закрыть», по центру пары кнопок
    // (`[OWNER]` 2026-11-18 08:13 и 08:20 «центрировать относительно кнопок», verbatim — KUMM PROJECT_HISTORY.md, entry 2026-11-18 08:11).
    // Шрифт и цвет — строки пути. [NOT-TESTED]
    // LVER_GAP — от низа кнопок до верха строки шрифта (до верха заглавных глаз видит ≈ 8.7 px: у Inter заглавная 0.73 кегля).
    const float LVER_PX = 11f, LVER_GAP = 6f;                                                  // [AI] 11 px — мельче строки пути (12 px)
    const FontStyle VER_STYLE = FontStyle.Bold;
    static readonly FontFamily VersionFont = SystemFamily("Cambria", "Georgia");

    static FontFamily SystemFamily(string name, string fallback)
    {
        try { return new FontFamily(name); }
        catch (ArgumentException) { return new FontFamily(fallback); }
    }
    const int SOLID_ALPHA = 64;
    static readonly Color VersionInk = Color.FromArgb(233, 213, 193);                          // LINE1_LINEAR меню, в sRGB
    // Подъём и высота строки шрифтов в долях кегля (hhea, как считает Chrome): базовые линии стоят там же, где в макете.
    const float OSWALD_ASC = 1.193f, OSWALD_LINE = 1.482f, INTER_ASC = .96875f, INTER_LINE = 1.2109f, INTER_UNDERLINE = 140f / 2048f;
    static readonly Color TitleInk = Metal.Html("#f7ecd6"), GameGold = Metal.Html("#ffd27e"), DlyaInk = Color.FromArgb(184, 255, 240, 215),
                          PathInk = Metal.Html("#e2d4ba"), LinkInk = Metal.Html("#eadcc2"), LinkGold = Metal.Html("#f2c977"), LinkHover = Color.White;

    const int WM_NCHITTEST = 0x84, WM_NCLBUTTONDOWN = 0xA1, WM_DPICHANGED = 0x02E0, HTCLIENT = 1, HTCAPTION = 2;
    const int WS_MINIMIZEBOX = 0x20000, WS_SYSMENU = 0x80000, CS_DROPSHADOW = 0x20000;
    [DllImport("user32.dll")] static extern bool ReleaseCapture();
    [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] static extern uint GetDpiForWindow(IntPtr hWnd);
    [DllImport("user32.dll")] static extern int SetWindowRgn(IntPtr hWnd, IntPtr hRgn, bool redraw);
    [DllImport("gdi32.dll")] static extern IntPtr ExtCreateRegion(IntPtr xform, int count, byte[] data);
    [StructLayout(LayoutKind.Sequential)] struct RECT { public int Left, Top, Right, Bottom; }

    // Надпись картины: контур букв, цвет; у ссылки — адрес и место, куда щёлкать.
    sealed class Run { public GraphicsPath Path; public Color Color; public string Url; public Rectangle Hit; }

    readonly Bitmap wallpaper = KrinikConanLauncher.LoadBitmap("res.wallpaper.jpg");
    readonly Bitmap logoGame = KrinikConanLauncher.LoadBitmap("res.logo-game.png"), logoPack = KrinikConanLauncher.LoadBitmap("res.logo-pack.png");
    readonly Bitmap frameTop = KrinikConanLauncher.LoadBitmap("res.frame_h.png"), frameLeft = KrinikConanLauncher.LoadBitmap("res.frame_v.png");
    readonly Bitmap frameBottom, frameRight;
    // Имена кнопок окна ставит Retext из таблицы языка (Ui).
    readonly CaptionButton minimize = new CaptionButton(false, ""), close = new CaptionButton(true, "");
    readonly ToolTip tips = new ToolTip();
    // Надписи картины строятся из контуров букв (дорого) и живут, пока не изменились их входы: шапка (название, игра, версии) — ключ headKey, ссылки —
    // linksKey; кэш картины перерисовывается, только когда меняется его ключ cacheKey (размер, масштаб, надписи, плашка версии лаунчера). До 2026-11-20
    // каждый Relayout (смена экрана, списка состояния, языка) строил все надписи заново и сбрасывал кэш: 282–304 мс перерисовки фона на 300 % на каждое
    // нажатие (баг 110; KUMM researches/efficient-code §0, §2.1–2.4). [NOT-TESTED]
    readonly List<List<Run>> head = new List<List<Run>>();
    List<Run> linkBlock = new List<Run>();
    readonly List<Run> links = new List<Run>();
    string headKey, linksKey, cacheKey;
    float headBottom;
    Bitmap cache;
    Size canvas;      // размер окна по раскладке; ClientSize Windows Forms урезает до размера экрана, картина — нет (нужно снимку)
    bool[] chips;     // сколы внешней кромки последней картины (true — не окно)
    // Столбик (plans/57, макеты KUIPS): золотая главная — наверху на постоянном месте, под ней — панель состояния, кнопки середины («Остановить»),
    // внизу — «Руководство», «Отзыв», «Удалить сборку» (`[OWNER]` 2026-11-18 08:41).
    MetalButton gold;
    bool goldOn = true;
    StatePanel panel;
    readonly List<MetalButton> mid = new List<MetalButton>(), low = new List<MetalButton>(), parts = new List<MetalButton>();
    MetalButton gameNotes, packNotes;
    Control aside;
    UpdatePlate plate;
    LangSwitch lang;
    ChooserOverlay chooser;
    Rectangle logoGameRect, logoPackRect;
    int dpi = 96, hoverLink = -1;
    bool placed, layingOut;

    public string Title { get; set; } = "";
    // Идёт установка или обновление (KUMM plan 54): окно не закрывается.
    public bool Busy { get; set; }
    public string GameName { get; set; } = "";
    public string GameVersion { get; set; } = "";
    public string PackVersion { get; set; } = "";
    public string LauncherVersion { get; set; } = "";
    // Строка плашки версии лаунчера («Лаунчер: 1.0.0») — на языке окна.
    public string LauncherLine { get; set; } = "";
    public BuildInfo.Link[] Links { get; set; } = new BuildInfo.Link[0];
    public Bitmap FrameH => frameTop;
    public Bitmap FrameV => frameLeft;

    public MetalWindow()
    {
        FormBorderStyle = FormBorderStyle.None;
        MaximizeBox = false;
        DoubleBuffered = true;
        AutoScaleMode = AutoScaleMode.None; // раскладку по масштабу делает Relayout, второй раз Windows Forms её не множит
        BackColor = Metal.Html("#16100a");
        // Низ — верхняя полоса, повёрнутая на 180°, правый край — левая (как в макете: transform: scale(-1, -1)).
        frameBottom = Turned(frameTop);
        frameRight = Turned(frameLeft);
        minimize.Click += (s, e) => WindowState = FormWindowState.Minimized;
        close.Click += (s, e) => Close();
        Controls.Add(minimize);
        Controls.Add(close);
        // Место окна ставит Place после раскладки (критерий 12): StartPosition = CenterScreen центровал окно в его малом начальном размере, а раскладка
        // растила его вправо и вниз за край экрана (`[OWNER]` 2026-11-18 15:55–15:56: окно внизу справа, обрезанное краями).
        StartPosition = FormStartPosition.Manual;
        // Стенд кадров (Frames): окно за пределами всех мониторов и без кнопки на панели задач — экран владельца остаётся его (EXP-0553). Обычный запуск
        // кнопку на панели задач с иконкой сборки имеет всегда (критерий 13).
        if (Frames.On) { ShowInTaskbar = false; Location = OffScreen; }
    }

    // Окно открывается по центру рабочей области монитора, на котором его запустили (там, где указатель мыши), целиком внутри неё (KUMM plans/57,
    // критерий 12; `[OWNER]` 2026-11-18 15:55–15:56 «нужно, чтобы он по центру работчего стола открывался»). Размер уже посчитан раскладкой. Стенд кадров
    // считает то же место, пишет его в журнал и ставит окно за пределы всех мониторов. [NOT-TESTED]
    internal static Point OffScreen => new Point(SystemInformation.VirtualScreen.Left - 30000, SystemInformation.VirtualScreen.Top - 30000);

    // on — монитор окна при повторной расстановке (окно не перепрыгивает на монитор, куда ушла мышь).
    void Place(Screen on = null)
    {
        var area = (on ?? Screen.FromPoint(Cursor.Position)).WorkingArea;
        int x = area.Left + (area.Width - Width) / 2, y = area.Top + (area.Height - Height) / 2;
        x = Math.Max(area.Left, Math.Min(x, area.Right - Width));
        y = Math.Max(area.Top, Math.Min(y, area.Bottom - Height));
        Log($"место окна: {x},{y} {Width}x{Height} в рабочей области {area.X},{area.Y} {area.Width}x{area.Height}" + (Frames.On ? " (стенд кадров: окно за пределами мониторов)" : ""));
        Location = Frames.On ? OffScreen : new Point(x, y);
        placedAt = Location;
        placed = true;
    }

    Point placedAt;

    // Окно выросло (плашка обновлений, табличка «Отзыв») или переехало на монитор с другим масштабом. Игрок окно не двигал — оно снова встаёт по центру
    // рабочей области (судья 2026-11-18, риск 14: плашка, пришедшая после показа, растила окно, и оно уже не стояло по центру); двигал — остаётся, где он
    // его поставил, целиком внутри рабочей области своего монитора. [NOT-TESTED]
    void KeepInside()
    {
        if (Frames.On) { Location = OffScreen; return; }
        if (Location == placedAt) { Place(Screen.FromControl(this)); return; }
        var area = Screen.FromControl(this).WorkingArea;
        Left = Math.Max(area.Left, Math.Min(Left, area.Right - Width));
        Top = Math.Max(area.Top, Math.Min(Top, area.Bottom - Height));
    }

    static Bitmap Turned(Bitmap b)
    {
        if (b == null) return null;
        var t = (Bitmap)b.Clone();
        t.RotateFlip(RotateFlipType.Rotate180FlipNone);
        return t;
    }

    // Подсказки кнопок окна — на языке окна.
    public void Retext()
    {
        tips.SetToolTip(minimize, Ui.T("caps.minimize"));
        tips.SetToolTip(close, Ui.T("caps.close"));
        minimize.AccessibleName = Ui.T("caps.minimize");
        close.AccessibleName = Ui.T("caps.close");
    }

    // Части окна регистрируются один раз; что из них видно, решает SetColumn на каждом экране.
    public void SetParts(MetalButton[] buttons, StatePanel state, UpdatePlate updates, LangSwitch language, ChooserOverlay choose, MetalButton notesGame, MetalButton notesPack)
    {
        panel = state; plate = updates; lang = language; chooser = choose; gameNotes = notesGame; packNotes = notesPack;
        Controls.Add(chooser);   // первый в Controls — верхний: выбор копии лежит над всем окном
        foreach (var b in buttons) { parts.Add(b); Controls.Add(b); b.Visible = false; }
        Controls.Add(panel);
        Controls.Add(plate);
        Controls.Add(lang);
        Controls.Add(lang.List);   // раскрытый список поднимается наверх сам (LangSwitch.Open → BringToFront)
        Controls.Add(gameNotes);
        Controls.Add(packNotes);
        plate.SizeChanged += (s, e) => Relayout();
        plate.VisibleChanged += (s, e) => Relayout();
    }

    // Экран столбика: главная (null — её нет), светится ли она, панель, середина и низ; остальные кнопки прячутся.
    public void SetColumn(MetalButton main, bool mainOn, StatePanel state, IList<MetalButton> middle, IList<MetalButton> bottom)
    {
        gold = main; goldOn = mainOn; panel = state;
        mid.Clear(); mid.AddRange(middle);
        low.Clear(); low.AddRange(bottom);
        foreach (var b in parts)
        {
            b.Visible = b == gold || mid.Contains(b) || low.Contains(b);
            b.Gold = b == gold;
        }
        if (gold != null) gold.Enabled = goldOn;
        Relayout();
    }

    // Табличка «Отзыв», пока открыта; от её размера зависит раскладка.
    public Control Aside
    {
        get => aside;
        set
        {
            aside = value;
            value.SizeChanged += (s, e) => Relayout();
            value.VisibleChanged += (s, e) => Relayout();
        }
    }

    // Идёт ли отрисовка частей в картинку (DrawToBitmap): таймер списка состояния подписывает такую отрисовку «Print», чтобы стенд отличал перерисовку
    // на экране от кадра (судья 2026-11-20, круг 5, находка 1: кадр стенда сам рисует список заново и прятал несостоявшуюся перерисовку). [NOT-TESTED]
    internal static bool InPicture;

    // Картина окна с его частями (без except) — то, что видит игрок; подложка выбора копии.
    public Bitmap Picture(Control except)
    {
        if (cache == null || cache.Size != canvas) Render();
        var shot = new Bitmap(canvas.Width, canvas.Height, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(shot)) g.DrawImage(cache, new Rectangle(Point.Empty, canvas), new Rectangle(Point.Empty, canvas), GraphicsUnit.Pixel);
        InPicture = true;
        try
        {
            for (int i = Controls.Count - 1; i >= 0; i--) // снизу вверх: первый в Controls — верхний
            {
                var c = Controls[i];
                if (c != except && c.Visible && c.Width > 0 && c.Height > 0) c.DrawToBitmap(shot, c.Bounds);
            }
        }
        finally { InPicture = false; }
        return shot;
    }

    public float Zoom => dpi / 96f;
    int Px(float logical) => (int)Math.Round(logical * Zoom);

    protected override CreateParams CreateParams
    {
        get
        {
            var cp = base.CreateParams;
            cp.Style |= WS_MINIMIZEBOX | WS_SYSMENU; // сворачивание щелчком по значку на панели задач
            cp.ClassStyle |= CS_DROPSHADOW;
            return cp;
        }
    }

    // Окно таскается за любое свободное место: картину, табличку и её надписи (но не кнопки и ссылки).
    public void DragBy(Control c)
    {
        if (c is ButtonBase) return;
        c.MouseDown += (s, e) =>
        {
            if (e.Button != MouseButtons.Left) return;
            ReleaseCapture();
            SendMessage(Handle, WM_NCLBUTTONDOWN, (IntPtr)HTCAPTION, IntPtr.Zero);
        };
        foreach (Control child in c.Controls) DragBy(child);
    }

    protected override void WndProc(ref Message m)
    {
        // Окно перенесли на монитор с другим масштабом: Windows предлагает место, раскладка — заново под новый DPI.
        // [NOT-TESTED] — второго монитора с другим масштабом на стенде нет; раскладка под чужой DPI проверена снимками 288 и 384 dpi.
        if (m.Msg == WM_DPICHANGED)
        {
            // Стенд с заданным DPI (снимок, кадры) масштаб Windows не принимает: иначе Windows двигала бы окно стенда к монитору (2026-11-18 15:55).
            if (ForcedDpi > 0) { m.Result = IntPtr.Zero; return; }
            dpi = (int)((long)m.WParam & 0xFFFF);
            var r = (RECT)Marshal.PtrToStructure(m.LParam, typeof(RECT));
            Location = new Point(r.Left, r.Top);
            Relayout();
            if (!placed) Place(); else KeepInside();
            m.Result = IntPtr.Zero;
            return;
        }
        base.WndProc(ref m);
        // Картина — «заголовок» окна (за неё таскают), кроме ссылок автора: по ним щёлкают.
        if (m.Msg == WM_NCHITTEST && (int)m.Result == HTCLIENT)
        {
            long lp = (long)m.LParam;
            var p = PointToClient(new Point((short)(lp & 0xFFFF), (short)((lp >> 16) & 0xFFFF)));
            if (LinkAt(p) < 0) m.Result = (IntPtr)HTCAPTION;
        }
    }

    int LinkAt(Point p)
    {
        for (int i = 0; i < links.Count; i++) if (links[i].Hit.Contains(p)) return i;
        return -1;
    }

    protected override void OnMouseMove(MouseEventArgs e)
    {
        base.OnMouseMove(e);
        SetHover(LinkAt(e.Location));
    }

    protected override void OnMouseLeave(EventArgs e)
    {
        base.OnMouseLeave(e);
        SetHover(-1);
    }

    void SetHover(int link)
    {
        if (link == hoverLink) return;
        if (hoverLink >= 0) Invalidate(links[hoverLink].Hit);
        hoverLink = link;
        Cursor = link >= 0 ? Metal.Hand : Cursors.Default;
        if (link >= 0) Invalidate(links[link].Hit);
    }

    protected override void OnMouseClick(MouseEventArgs e)
    {
        base.OnMouseClick(e);
        int i = e.Button == MouseButtons.Left ? LinkAt(e.Location) : -1;
        if (i >= 0) Process.Start(new ProcessStartInfo(links[i].Url) { UseShellExecute = true });
    }

    // Масштаб окна — Windows (DPI своего монитора) или стенд: снимок и кадры раскладываются под заданный DPI.
    static int ForcedDpi => Snapshot.dpi > 0 ? Snapshot.dpi : Frames.Dpi;

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        try { int d = (int)GetDpiForWindow(Handle); dpi = d > 0 ? d : DeviceDpi; }
        catch (EntryPointNotFoundException) { dpi = DeviceDpi; } // Windows старше 10 1607
        if (ForcedDpi > 0) dpi = ForcedDpi;
    }

    protected override void OnLoad(EventArgs e)
    {
        base.OnLoad(e);
        Relayout();
        if (!placed) Place();
        if (Snapshot.file != null)
        {
            if (Snapshot.report && aside != null) aside.Visible = true;
            BeginInvoke((Action)(() => { SaveSnapshot(Snapshot.file); Close(); }));
        }
    }

    // Снимок для проверки без 4K-экрана: KRINIK_LAUNCHER_SNAPSHOT=<файл.png>;<dpi>[;report] — окно раскладывается под этот DPI (report —
    // с открытой табличкой «Отзыв»), рисуется в картинку тем же кодом, что на экране (картина, кнопки, сколы каймы — прозрачными),
    // и закрывается. У игрока этой переменной нет.
    static readonly (string file, int dpi, bool report) Snapshot = ReadSnapshotVariable();
    public static bool SnapshotMode => Snapshot.file != null;

    // Проверка кликов по живому окну (KUMM plan 54): KRINIK_LAUNCHER_NOACTIVATE=1 — окно показывается, не забирая фокус у того, кто работает
    // за компьютером; кнопки нажимаются сообщением BM_CLICK. Стенд кадров (Frames) тоже не берёт фокус. У игрока этих переменных нет.
    protected override bool ShowWithoutActivation => Environment.GetEnvironmentVariable("KRINIK_LAUNCHER_NOACTIVATE") == "1" || Frames.On;

    static (string, int, bool) ReadSnapshotVariable()
    {
        var v = Environment.GetEnvironmentVariable("KRINIK_LAUNCHER_SNAPSHOT");
        if (string.IsNullOrEmpty(v)) return (null, 0, false);
        var parts = v.Split(';');
        return (parts[0], parts.Length > 1 && int.TryParse(parts[1], out int d) ? d : 0, parts.Length > 2 && parts[2] == "report");
    }

    public void SaveSnapshot(string file)
    {
        using (var shot = Picture(null))
        {
            if (chips != null && chips.Length == canvas.Width * canvas.Height)
                for (int y = 0; y < canvas.Height; y++)
                    for (int x = 0; x < canvas.Width; x++)
                        if (chips[y * canvas.Width + x]) shot.SetPixel(x, y, Color.Transparent);
            shot.Save(file, ImageFormat.Png);
        }
    }

    protected override void OnResize(EventArgs e)
    {
        base.OnResize(e);
        InvalidateCache();
    }

    // Столбик макетов KUIPS (.col: top 118, bottom 28, ширина 270, зазор 9) и плашка версии лаунчера (.lver), переключатель языка (.lang).
    const float COL_TOP = 118f, ST_TOP = 4f, PROG_TOP = 2f, PLATE_TOP = 136f;
    const float LVER_TOP = 60f, LVER_W = 82f, LVER_H = 20f, LVER_RIM = 1.5f, LVER_PAD = 7f, LVER_CUT = 5f, LANG_RIGHT = 110f;
    Rectangle lverRect;

    // Раскладка в пикселях экрана: шапка сверху слева, плашка обновлений под ней, столбик справа — главная наверху, панель, середина, низ у нижнего
    // края; ссылки слева внизу; раскрытый «Отзыв» — слева от столбика над ссылками; не влезло — окно растёт вниз, картина его заполняет.
    public void Relayout()
    {
        if (layingOut || panel == null || !IsHandleCreated) return;
        layingOut = true;
        string ck = null;
        try
        {
            float s = Zoom;
            int w = Px(WIN_W), h = Px(WIN_H);
            foreach (var b in parts) SetPixelFont(b, BUTTON_FONT * s);
            // Длинная надпись золотой кнопки — кеглем 22 вместо 28 (макет: .gold.long у надписи длиннее 8 букв).
            if (gold != null) SetPixelFont(gold, (gold.Text.Length > 8 ? INSTALL_FONT : PLAY_FONT) * s);
            string hk = string.Join("|", s, Title, GameName, GameVersion, PackVersion, gameNotes?.Text, packNotes?.Text);
            if (hk != headKey)
            {
                foreach (var block in head) foreach (var run in block) run.Path.Dispose();
                head.Clear();
                headBottom = LayoutTitle(s);
                headKey = hk;
            }
            float titleBottom = headBottom;
            int colW = Px(COL_W), colX = w - Px(COL_RIGHT) - colW;
            float linksH = Links.Length * LINK_PX * LINK_LINE * s;

            if (plate != null && plate.Visible)
            {
                plate.Arrange(s);
                plate.Location = new Point(Px(LINKS_LEFT), (int)Math.Round(Math.Max(PLATE_TOP * s, titleBottom + 8 * s)));
                titleBottom = plate.Bottom;
            }
            if (aside != null) ScaleTree(aside, s);
            bool asideOn = aside != null && aside.Visible;
            if (asideOn)
            {
                KrinikConanLauncher.FitWidth(aside, colX - Px(ASIDE_GAP) - Px(LINKS_LEFT));
                float need = titleBottom + (ASIDE_BELOW_TITLE + ASIDE_ABOVE_LINKS + LINKS_BOTTOM) * s + aside.Height + linksH;
                if (need > h) h = (int)Math.Ceiling(need);
            }
            else if (plate != null && plate.Visible)
            {
                float need = titleBottom + (ASIDE_ABOVE_LINKS + LINKS_BOTTOM) * s + linksH;
                if (need > h) h = (int)Math.Ceiling(need);
            }

            // Столбик сверху вниз: золотая главная, панель состояния, середина; низ — от нижнего края вверх.
            float y = COL_TOP * s;
            if (gold != null) { gold.Bounds = new Rectangle(colX, (int)Math.Round(y), colW, Px(PLAY_H)); y += (PLAY_H + COL_GAP) * s; }
            panel.Visible = !panel.Empty;
            if (!panel.Empty)
            {
                y += (panel.What != null ? PROG_TOP : ST_TOP) * s;
                int ph = panel.Measure(colW, s);
                panel.Bounds = new Rectangle(colX, (int)Math.Round(y), colW, ph);
                y += ph + COL_GAP * s;
            }
            foreach (var b in mid) { b.Bounds = new Rectangle(colX, (int)Math.Round(y), colW, Px(BUTTON_H)); y += (BUTTON_H + COL_GAP) * s; }
            float lowH = low.Count * BUTTON_H * s + Math.Max(0, low.Count - 1) * COL_GAP * s;
            if (y + lowH + COL_BOTTOM * s > h) h = (int)Math.Ceiling(y + lowH + COL_BOTTOM * s);
            float ly = h - COL_BOTTOM * s - lowH;
            foreach (var b in low) { b.Bounds = new Rectangle(colX, (int)Math.Round(ly), colW, Px(BUTTON_H)); ly += (BUTTON_H + COL_GAP) * s; }

            float linksTop = h - LINKS_BOTTOM * s - linksH;
            var lk = new StringBuilder().Append(s).Append('|').Append(linksTop);
            foreach (var l in Links) lk.Append('|').Append(l.Text).Append('\u0001').Append(l.Label).Append('\u0001').Append(l.Url);
            if (lk.ToString() != linksKey)
            {
                foreach (var run in linkBlock) run.Path.Dispose();
                linkBlock = new List<Run>();
                links.Clear();
                hoverLink = -1;
                LayoutLinks(linksTop, s);
                linksKey = lk.ToString();
            }
            if (asideOn) aside.Location = new Point(Px(LINKS_LEFT), (int)Math.Round(linksTop - ASIDE_ABOVE_LINKS * s) - aside.Height);

            var size = new Size(Px(CAP_W), Px(CAP_H));
            close.Bounds = new Rectangle(w - Px(CAPS_RIGHT) - size.Width, Px(CAPS_TOP), size.Width, size.Height);
            minimize.Bounds = new Rectangle(close.Left - Px(CAPS_GAP) - size.Width, Px(CAPS_TOP), size.Width, size.Height);
            if (lang != null)
            {
                var ls = LangSwitch.SizeAt(s);
                lang.Bounds = new Rectangle(w - Px(LANG_RIGHT) - ls.Width, Px(CAPS_TOP), ls.Width, ls.Height);
                lang.List.Arrange(s, lang.Right, Px(LangSwitch.LIST_TOP));
            }
            // Плашка версии лаунчера: по центру под парой кнопок окна, не уже пары; длинный номер растит её влево (судья 2026-11-18, риск 1).
            if (!string.IsNullOrEmpty(LauncherLine))
            {
                float tw = Lettering.Advance(LauncherLine, Fonts.Body, FontStyle.Regular, LVER_PX * s);
                int pw = Math.Max(Px(LVER_W), (int)Math.Ceiling(tw + 2 * (LVER_PAD + LVER_RIM) * s)), pairCx = (minimize.Left + close.Right) / 2;
                int px = Math.Min(pairCx - pw / 2, close.Right - pw);
                lverRect = new Rectangle(px, Px(LVER_TOP), pw, Px(LVER_H));
            }
            if (chooser != null && chooser.Visible) chooser.Arrange(new Size(w, h), s);
            canvas = new Size(w, h);
            ClientSize = canvas;
            if (placed) KeepInside();
            ck = string.Join("|", w, h, s, headKey, linksKey, LauncherLine, lverRect);
        }
        finally { layingOut = false; }
        // Кнопки и панель, которые сдвинулись или поменяли текст, Windows Forms перерисует сама (смена границ и их собственный Invalidate); картина —
        // только при смене её входов.
        if (ck != cacheKey) { cacheKey = ck; InvalidateCache(); }
    }

    // Плашка версии лаунчера (.lver): приглушённый кант (#8a6a40 → #4a3018) с рублеными углами, тёмное лицо, 11 px Inter #d2c4a6, без тени —
    // чтобы не походила на кнопку (`[OWNER]` 2026-11-18 10:33, 10:36).
    void DrawVersionPlate(Graphics g)
    {
        if (lverRect.Width <= 0 || string.IsNullOrEmpty(LauncherLine)) return;
        float s = Zoom;
        var outer = new RectangleF(lverRect.X, lverRect.Y, lverRect.Width, lverRect.Height);
        using (var path = Metal.Chamfer(outer, LVER_CUT * s))
        using (var b = new LinearGradientBrush(RectangleF.Inflate(outer, 0, 1), Metal.Html("#8a6a40"), Metal.Html("#4a3018"), 90f)) g.FillPath(b, path);
        var face = RectangleF.Inflate(outer, -LVER_RIM * s, -LVER_RIM * s);
        using (var path = Metal.Chamfer(face, Math.Max(1f, (LVER_CUT - 1) * s)))
        using (var b = new LinearGradientBrush(RectangleF.Inflate(face, 0, 1), Metal.Html("#2a2118"), Metal.Html("#15100a"), 90f)) g.FillPath(b, path);
        float px = LVER_PX * s, tw = Lettering.Advance(LauncherLine, Fonts.Body, FontStyle.Regular, px);
        float baseline = face.Top + (face.Height - px) / 2 + px * INTER_ASC - px * (INTER_ASC - .73f) / 2;
        using (var path = new GraphicsPath())
        using (var b = new SolidBrush(Metal.Html("#d2c4a6")))
        {
            Lettering.Add(path, LauncherLine, Fonts.Body, FontStyle.Regular, px, 0f, face.Left + (face.Width - tw) / 2, baseline);
            g.FillPath(b, path);
        }
    }

    // Табличка «Отзыв» задана в логических единицах (отступы — пиксели при 96 dpi, шрифты — пункты); окно само множит их на свой масштаб,
    // раз Windows Forms этого не делает (AutoScaleMode.None), — и на мониторе с другим масштабом тоже. Логические значения помнит с первого раза.
    readonly Dictionary<Control, (Padding padding, Padding margin, float pt)> logical = new Dictionary<Control, (Padding, Padding, float)>();

    void ScaleTree(Control c, float s)
    {
        if (!logical.TryGetValue(c, out var l)) logical[c] = l = (c.Padding, c.Margin, c.Font.SizeInPoints);
        c.Padding = ScalePadding(l.padding, s);
        c.Margin = ScalePadding(l.margin, s);
        if (c is OutlinedLabel || c is ButtonBase)
        {
            float px = l.pt * 96f / 72f * s;
            if (c.Font.Unit != GraphicsUnit.Pixel || Math.Abs(c.Font.Size - px) > .01f) c.Font = new Font(c.Font.FontFamily, px, c.Font.Style, GraphicsUnit.Pixel);
        }
        foreach (Control child in c.Controls) ScaleTree(child, s);
    }

    static Padding ScalePadding(Padding p, float s) =>
        new Padding((int)Math.Round(p.Left * s), (int)Math.Round(p.Top * s), (int)Math.Round(p.Right * s), (int)Math.Round(p.Bottom * s));

    static void SetPixelFont(Control c, float px)
    {
        if (c.Font.Unit == GraphicsUnit.Pixel && Math.Abs(c.Font.Size - px) < .01f) return;
        c.Font = new Font("Georgia", px, FontStyle.Bold, GraphicsUnit.Pixel);
    }

    static Run TextRun(string text, FontFamily family, float px, float spacing, float x, float baseline, Color color, FontStyle style = FontStyle.Regular)
    {
        var path = new GraphicsPath();
        Lettering.Add(path, text, family, style, px, spacing, x, baseline);
        return new Run { Path = path, Color = color };
    }

    // Шапка (.top макета): логотип игры, логотип сборки и блок заголовка в ряд, каждый по центру общей высоты.
    // Под заголовком по центру — название игры; «для» висит слева от него и в центровку не входит (18:37). Возвращает низ шапки.
    float LayoutTitle(float s)
    {
        float top = TOP * s;
        float hG = LOGO_GAME_H * s, wG = logoGame != null ? hG * logoGame.Width / logoGame.Height : 0f;
        float hP = LOGO_PACK_H * s, wP = logoPack != null ? hP * logoPack.Width / logoPack.Height : 0f;
        float titleBox = TITLE_PX * TITLE_LINE * s, gameBox = GAME_PX * OSWALD_LINE * s;
        float blockH = titleBox + GAME_GAP * s + gameBox, rowH = Math.Max(Math.Max(hG, hP), blockH);
        float x = LEFT * s;
        logoGameRect = Rectangle.Round(new RectangleF(x, top + (rowH - hG) / 2, wG, hG));
        x += wG + TOP_GAP * s;
        logoPackRect = Rectangle.Round(new RectangleF(x, top + (rowH - hP) / 2, wP, hP));
        x += wP + TOP_GAP * s;
        float blockTop = top + (rowH - blockH) / 2;

        float titlePx = TITLE_PX * s, gamePx = GAME_PX * s, dlyaPx = DLYA_PX * s;
        string game = GameName.ToUpperInvariant();
        float titleW = Lettering.Width(Title, Fonts.Title, FontStyle.Regular, titlePx, TITLE_SPACING * titlePx);
        float gameW = Lettering.Width(game, Fonts.GameName, FontStyle.Regular, gamePx, GAME_SPACING * gamePx);
        float blockW = Math.Max(TITLE_INDENT * s + titleW, gameW);
        float titleBase = blockTop + (titleBox - TITLE_PX * OSWALD_LINE * s) / 2 + TITLE_PX * OSWALD_ASC * s;
        float gameTop = blockTop + titleBox + GAME_GAP * s, gameX = x + (blockW - gameW) / 2;
        float dlyaBottom = gameTop + gameBox - DLYA_RAISE * s;
        float dlyaBase = dlyaBottom - DLYA_PX * OSWALD_LINE * s + DLYA_PX * OSWALD_ASC * s;
        head.Add(new List<Run>
        {
            TextRun(Title, Fonts.Title, titlePx, TITLE_SPACING * titlePx, x + TITLE_INDENT * s, titleBase, TitleInk),
            TextRun(game, Fonts.GameName, gamePx, GAME_SPACING * gamePx, gameX, gameTop + GAME_PX * OSWALD_ASC * s, GameGold)
            // «для» убрано: владелец 2026-10-31 19:57 «из лаунчера для убираем» (было слева от названия игры с 18:37).
        });
        return Math.Max(top + rowH, LayoutVersions(s));
    }

    // Строка версии под каждым логотипом (константы VER_*). Возвращает низ самой нижней строки.
    // [TESTED: 2026-11-02 · snapshots 288/144/96 dpi, each version centred under its logo · KUMM testcases/reports/2026-11-02_conan-release-0.9.0.md]
    float LayoutVersions(float s)
    {
        float bottom = 0f, px = VER_PX * s;
        var block = new List<Run>();
        var fam = VersionFont;
        float asc = (float)fam.GetCellAscent(VER_STYLE) / fam.GetEmHeight(VER_STYLE), line = (float)fam.GetLineSpacing(VER_STYLE) / fam.GetEmHeight(VER_STYLE);
        var placed = new List<(float cx, MetalButton notes)>();
        foreach (var (logo, rect, text, notes) in new[] { (logoGame, logoGameRect, GameVersion, gameNotes), (logoPack, logoPackRect, PackVersion, packNotes) })
        {
            if (logo == null || string.IsNullOrEmpty(text)) { if (notes != null) notes.Visible = false; continue; }
            RectangleF solid = SolidBox(logo);
            float cx = rect.X + (solid.X + solid.Width / 2) * rect.Width;
            float lineTop = rect.Y + solid.Bottom * rect.Height + VER_GAP * s;
            float w = Lettering.Width(text, fam, VER_STYLE, px, VER_SPACING * px);
            block.Add(TextRun(text, fam, px, VER_SPACING * px, cx - w / 2, lineTop + px * asc, VersionInk, VER_STYLE));
            bottom = Math.Max(bottom, lineTop + px * line);
            if (notes != null) placed.Add((cx, notes));
        }
        // «Что нового» — каждая по центру под своей версией, обе в один ряд под нижней из строк версий: строки стоят на разной высоте
        // (логотипы разные), а кнопки вразнобой глаз читает как сбой (снимок 2026-11-17 15:02).
        float top = bottom + NOTES_GAP * s;
        foreach (var (cx, notes) in placed)
        {
            SetPixelFont(notes, NOTES_FONT * s);
            int bw = TextRenderer.MeasureText(notes.Text, notes.Font).Width + Px(2 * NOTES_PAD), bh = Px(NOTES_H);
            notes.Bounds = new Rectangle((int)Math.Round(cx - bw / 2f), (int)Math.Round(top), bw, bh);
            notes.Visible = true;
            bottom = Math.Max(bottom, top + bh);
        }
        head.Add(block);
        return bottom;
    }

    // Сплошная часть картинки (альфа ≥ SOLID_ALPHA) в долях её ширины и высоты; у логотипа сборки снизу мягкая тень, её не считаем.
    // Проход по каждому пикселю делается один раз на картинку: логотипы не меняются, а LayoutVersions зовётся на каждый Relayout (баг 110, 2026-11-20 —
    // полный проход на каждое событие, KUMM researches/efficient-code §0). [NOT-TESTED]
    static readonly Dictionary<Bitmap, RectangleF> solidBoxes = new Dictionary<Bitmap, RectangleF>();
    static RectangleF SolidBox(Bitmap b)
    {
        if (!solidBoxes.TryGetValue(b, out var box)) solidBoxes[b] = box = ScanSolidBox(b);
        return box;
    }

    static RectangleF ScanSolidBox(Bitmap b)
    {
        var data = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        try
        {
            var row = new byte[data.Stride];
            int minX = b.Width, maxX = -1, minY = b.Height, maxY = -1;
            for (int y = 0; y < b.Height; y++)
            {
                Marshal.Copy(data.Scan0 + y * data.Stride, row, 0, data.Stride);
                for (int x = 0; x < b.Width; x++)
                    if (row[x * 4 + 3] >= SOLID_ALPHA) { if (x < minX) minX = x; if (x > maxX) maxX = x; if (y < minY) minY = y; maxY = y; }
            }
            if (maxX < 0) return new RectangleF(0f, 0f, 1f, 1f);
            return new RectangleF((float)minX / b.Width, (float)minY / b.Height, (float)(maxX - minX + 1) / b.Width, (float)(maxY - minY + 1) / b.Height);
        }
        finally { b.UnlockBits(data); }
    }

    // Ссылки автора (.links): без заголовка (18:22 «автор сборки - убрать заголовок»), строка «Почта: адрес», адрес — золотом, подчёркнут.
    void LayoutLinks(float top, float s)
    {
        float px = LINK_PX * s, line = LINK_PX * LINK_LINE * s;
        float thickness = Math.Max(1f, (float)Math.Round(INTER_UNDERLINE * px));
        var block = new List<Run>();
        for (int i = 0; i < Links.Length; i++)
        {
            var l = Links[i];
            float baseline = top + i * line + (line - LINK_PX * INTER_LINE * s) / 2 + LINK_PX * INTER_ASC * s, x = LINKS_LEFT * s;
            string lead = l.Text + BuildInfo.Separator;
            block.Add(TextRun(lead, Fonts.Body, px, 0f, x, baseline, LinkInk));
            x += Lettering.Advance(lead, Fonts.Body, FontStyle.Regular, px);
            float width = Lettering.Advance(l.Label, Fonts.Body, FontStyle.Regular, px);
            var link = TextRun(l.Label, Fonts.Body, px, 0f, x, baseline, LinkGold);
            using (var glyphs = (GraphicsPath)link.Path.Clone())
                Lettering.Underline(glyphs, link.Path, x, x + width, (float)Math.Round(baseline + UNDERLINE_OFFSET * s), thickness);
            link.Url = l.Url;
            link.Hit = Rectangle.Round(RectangleF.FromLTRB(x, baseline - LINK_PX * INTER_ASC * s, x + width, baseline + (LINK_PX * (INTER_LINE - INTER_ASC) + UNDERLINE_OFFSET) * s + thickness));
            block.Add(link);
            links.Add(link);
        }
        linkBlock = block;
    }

    void InvalidateCache()
    {
        cache?.Dispose();
        cache = null;
        Invalidate(true);
    }

    protected override void OnPaintBackground(PaintEventArgs e)
    {
        if (canvas.Width <= 0 || canvas.Height <= 0) return;
        if (cache == null || cache.Size != canvas) Render();
        var r = Rectangle.Intersect(e.ClipRectangle, new Rectangle(Point.Empty, cache.Size));
        e.Graphics.DrawImage(cache, r, r, GraphicsUnit.Pixel);
    }

    // Под мышью ссылка светлеет: поверх золота из кэша — те же буквы белым.
    // [NOT-TESTED] — подсветка глазом не снята: мышь владельца не трогаю, а поддельный WM_MOUSEMOVE сразу гасится WM_MOUSELEAVE.
    // Попадание по ссылке проверено: WM_NCHITTEST над адресом — HTCLIENT, над картиной и над «Почта:» — HTCAPTION.
    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        if (hoverLink < 0 || hoverLink >= links.Count) return;
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        using (var brush = new SolidBrush(LinkHover)) e.Graphics.FillPath(brush, links[hoverLink].Path);
    }

    // Картина — два слоя (баг 110, KUMM researches/efficient-code §2.4): нижний — обои, затемнение, логотипы и рамка, зависит только от размера окна и
    // мест логотипов (≈ 220 мс на 300 %, рисуется при рождении окна и при смене размера); верхний — надписи и плашка версии лаунчера поверх копии нижнего
    // (≈ 60 мс, рисуется, когда меняется текст шапки, ссылок или плашки). Рамка теперь под надписями: надписи до краёв окна не доходят. [NOT-TESTED]
    Bitmap baseLayer;
    string baseKey;

    void Render() { using (Perf("MetalWindow.Render")) RenderNow(); }

    void RenderNow()
    {
        int w = canvas.Width, h = canvas.Height;
        string bk = string.Join("|", w, h, logoGameRect, logoPackRect);
        if (baseLayer == null || bk != baseKey) { baseLayer?.Dispose(); baseLayer = RenderBase(w, h); baseKey = bk; }
        cache?.Dispose();
        cache = new Bitmap(w, h, PixelFormat.Format32bppPArgb);
        using (var g = Graphics.FromImage(cache))
        {
            g.CompositingMode = CompositingMode.SourceCopy;
            g.DrawImageUnscaled(baseLayer, 0, 0);
            g.CompositingMode = CompositingMode.SourceOver;
            Quality(g);
            foreach (var block in head) DrawLettering(g, block);
            DrawLettering(g, linkBlock);
            DrawVersionPlate(g);
        }
    }

    Bitmap RenderBase(int w, int h)
    {
        var layer = new Bitmap(w, h, PixelFormat.Format32bppPArgb);
        using (var g = Graphics.FromImage(layer))
        {
            g.Clear(BackColor);
            Quality(g);
            DrawWallpaper(g, w, h);
            DrawShade(g, w, h);
            DrawImage(g, logoGame, logoGameRect);
            DrawImage(g, logoPack, logoPackRect);
            try { DrawFrame(g, w, h); }
            catch (Exception ex) when (ex is ArgumentException || ex is ExternalException || ex is InvalidOperationException) { Log("рамка не нарисовалась: " + ex); }
        }
        return layer;
    }

    static void Quality(Graphics g)
    {
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        // Смешение — как в браузере макета, в sRGB без гамма-коррекции: с HighQuality затемнение .82 выходит заметно светлее макета.
        g.CompositingQuality = CompositingQuality.AssumeLinear;
        g.SmoothingMode = SmoothingMode.AntiAlias;
    }

    // Замер времени (баг 110): с KRINIK_LAUNCHER_PERF=1 журнал получает «perf: <мс от старта> <что> <мс> ms» на каждое обновление экрана, перерисовку
    // картины и списка состояния — по этим строкам стенд (self.mjs, кейс perf) судит бюджет. Без переменной строк нет; часы PERF_CLOCK идут всегда,
    // это один Stopwatch без опроса (судья 2026-11-20, круг 5, находка 6). [NOT-TESTED]
    internal static IDisposable Perf(string what) => PERF_ON ? new PerfSpan(what) : null;
    // Отметка события без длительности («perf: <мс от старта> <что> 0.0 ms»): запрос перерисовки списка состояния. Окно стенда стоит вне экрана, и
    // Windows не шлёт ему WM_PAINT вовсе (2026-11-20: ни одной перерисовки на экране за весь кейс, все строки отрисовки — кадры), так что стенд судит
    // о перерисовке по самому запросу. [NOT-TESTED]
    internal static void PerfMark(string what)
    {
        if (PERF_ON) Log("perf: " + PERF_CLOCK.Elapsed.TotalMilliseconds.ToString("0", System.Globalization.CultureInfo.InvariantCulture) + " " + what + " 0.0 ms");
    }
    static readonly bool PERF_ON = Environment.GetEnvironmentVariable("KRINIK_LAUNCHER_PERF") == "1";
    static readonly Stopwatch PERF_CLOCK = Stopwatch.StartNew();
    sealed class PerfSpan : IDisposable
    {
        readonly string what;
        readonly double at = PERF_CLOCK.Elapsed.TotalMilliseconds;
        public PerfSpan(string w) { what = w; }
        public void Dispose()
        {
            var inv = System.Globalization.CultureInfo.InvariantCulture;
            Log("perf: " + at.ToString("0", inv) + " " + what + " " + (PERF_CLOCK.Elapsed.TotalMilliseconds - at).ToString("0.0", inv) + " ms");
        }
    }

    // Журнал ошибок рисования — в %TEMP%\KrinikConanLauncher.log: окно должно открыться и без рамки, а причина — найтись.
    // Пишут два лаунчера разом (самообновление: прежний ждёт сигнала нового) — занятый файл даёт IOException; несколько коротких попыток, иначе строка
    // пропадала (стенд 2026-11-17 20:55: «лаунчер обновлён до 1.0.1» прежнего не дошла до журнала). [NOT-TESTED]
    // Каждая строка несёт номер процесса «[pid]»: при самообновлении и на стенде в один журнал пишут два лаунчера, и кейс perf стенда судит только
    // первый (судья 2026-11-20, круг 5, находка 2: новый лаунчер наследует KRINIK_LAUNCHER_PERF, и его отрисовка попадала в бюджет прежнего). [NOT-TESTED]
    static readonly string LOG_PID = "[" + Process.GetCurrentProcess().Id.ToString(System.Globalization.CultureInfo.InvariantCulture) + "] ";
    internal static void Log(string text)
    {
        string file = Path.Combine(Path.GetTempPath(), "KrinikConanLauncher.log"), line = DateTime.Now.ToString("s") + " " + LOG_PID + text + Environment.NewLine;
        for (int i = 0; i < 10; i++)
        {
            try { File.AppendAllText(file, line); return; }
            catch (IOException) { System.Threading.Thread.Sleep(15); }
            catch (UnauthorizedAccessException) { return; }
        }
    }

    // Волпейпер — по размеру окна с обрезкой лишнего, только уменьшение из 4K-исходника (HOUSE_RULES 17.3).
    void DrawWallpaper(Graphics g, int w, int h)
    {
        if (wallpaper == null) return;
        float k = Math.Max((float)w / wallpaper.Width, (float)h / wallpaper.Height);
        float dw = wallpaper.Width * k, dh = wallpaper.Height * k;
        DrawImage(g, wallpaper, Rectangle.Round(new RectangleF((w - dw) / 2, (h - dh) / 2, dw, dh)));
    }

    static void DrawImage(Graphics g, Bitmap image, Rectangle dest)
    {
        if (image == null || dest.Width <= 0 || dest.Height <= 0) return;
        using (var ia = new ImageAttributes())
        {
            ia.SetWrapMode(WrapMode.TileFlipXY); // без светлой каймы по краю при уменьшении
            g.DrawImage(image, dest, 0, 0, image.Width, image.Height, GraphicsUnit.Pixel, ia);
        }
    }

    // Затемнение под текстом (18:32 «затемнение под текстом ок верни») — три градиента ::before макета 11, цвет rgb(6,4,2):
    // сверху вниз .78 → .35 на 22 % → 0 на 34 %; снизу вверх .82 → 0 на 38 %; справа налево .82 → .55 на 26 % → 0 на 40 %.
    static void DrawShade(Graphics g, int w, int h)
    {
        Shade(g, new RectangleF(0, 0, w, h), 90f, (.78f, 0f), (.35f, .22f), (0f, .34f), (0f, 1f));
        Shade(g, new RectangleF(0, 0, w, h), 90f, (0f, 0f), (0f, .62f), (.82f, 1f));
        Shade(g, new RectangleF(0, 0, w, h), 180f, (.82f, 0f), (.55f, .26f), (0f, .40f), (0f, 1f));
    }

    static void Shade(Graphics g, RectangleF r, float angle, params (float alpha, float pos)[] stops)
    {
        // Кисть чуть шире окна: у LinearGradientBrush на самом краю бывает пиксель цвета с другого конца.
        using (var brush = new LinearGradientBrush(RectangleF.Inflate(r, 1, 1), Color.Black, Color.Black, angle))
        {
            var blend = new ColorBlend(stops.Length);
            for (int i = 0; i < stops.Length; i++) { blend.Colors[i] = Color.FromArgb((int)Math.Round(stops[i].alpha * 255), 6, 4, 2); blend.Positions[i] = stops[i].pos; }
            brush.InterpolationColors = blend;
            g.FillRectangle(brush, r);
        }
    }

    // Надписи картины — как .sh макета: две тени (0 0 6px rgba(0,0,0,.85) и 0 1px 2px #000), поверх — буквы.
    void DrawLettering(Graphics g, List<Run> block)
    {
        if (block.Count == 0) return;
        float s = Zoom;
        using (var all = new GraphicsPath())
        {
            // Пустой контур (пустая строка) AddPath не принимает — тот же дефект, что у Look.Lettered (стенд 2026-11-18 15:42).
            foreach (var run in block) if (run.Path.PointCount > 0) all.AddPath(run.Path, false);
            if (all.PointCount == 0) return;
            Lettering.Shadow(g, all, 0f, 0f, 6f * s, Color.FromArgb(217, 0, 0, 0));
            Lettering.Shadow(g, all, 0f, 1f * s, 2f * s, Color.Black);
        }
        foreach (var run in block)
            using (var brush = new SolidBrush(run.Color)) g.FillPath(brush, run.Path);
    }

    // Кайма — утверждённый сырой металл play 7 (18:53), 3 логических пикселя: полосы с прозрачностью растянуты по сторонам окна;
    // верх и низ лежат поверх боков (в углах концы заходят друг на друга), низ темнее (.82), правый край — (.86). Ни заклёпок, ни гладкого прута.
    void DrawFrame(Graphics g, int w, int h)
    {
        if (frameTop == null || frameLeft == null) return;
        int b = Math.Max(1, Px(FRAME));
        using (var layer = new Bitmap(w, h, PixelFormat.Format32bppPArgb))
        {
            using (var lg = Graphics.FromImage(layer))
            {
                lg.InterpolationMode = InterpolationMode.HighQualityBicubic;
                lg.PixelOffsetMode = PixelOffsetMode.HighQuality;
                lg.CompositingQuality = CompositingQuality.AssumeLinear;
                Strip(lg, frameLeft, new Rectangle(0, 0, b, h), 1f);
                Strip(lg, frameRight, new Rectangle(w - b, 0, b, h), .86f);
                Strip(lg, frameTop, new Rectangle(0, 0, w, b), 1f);
                Strip(lg, frameBottom, new Rectangle(0, h - b, w, b), .82f);
            }
            var old = g.InterpolationMode;
            g.InterpolationMode = InterpolationMode.NearestNeighbor;
            g.DrawImage(layer, new Rectangle(0, 0, w, h), 0, 0, w, h, GraphicsUnit.Pixel);
            g.InterpolationMode = old;
            CutChips(layer, b);
        }
    }

    static void Strip(Graphics g, Bitmap strip, Rectangle dest, float brightness)
    {
        using (var ia = new ImageAttributes())
        {
            ia.SetWrapMode(WrapMode.TileFlipXY);
            if (brightness != 1f) ia.SetColorMatrix(new ColorMatrix { Matrix00 = brightness, Matrix11 = brightness, Matrix22 = brightness });
            g.DrawImage(strip, dest, 0, 0, strip.Width, strip.Height, GraphicsUnit.Pixel, ia);
        }
    }

    // Сколы внешней кромки: от края окна внутрь, пока металл прозрачнее половины, — это не окно; дальше — окно (там картина под каймой,
    // как в макете). Форма окна — строки из отрезков, одинаковые соседние строки сливаются; Windows получает её одним регионом.
    void CutChips(Bitmap layer, int b)
    {
        int w = layer.Width, h = layer.Height, band = Math.Min(b + 1, Math.Min(w, h) / 2);
        var data = layer.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, layer.PixelFormat);
        byte[] px;
        int stride = data.Stride;
        try { px = new byte[stride * h]; Marshal.Copy(data.Scan0, px, 0, px.Length); }
        finally { layer.UnlockBits(data); }
        bool Solid(int x, int y) => px[y * stride + x * 4 + 3] >= 128;
        var cut = new bool[w * h];
        for (int x = 0; x < w; x++)
        {
            for (int y = 0; y < band && !Solid(x, y); y++) cut[y * w + x] = true;
            for (int y = h - 1; y >= h - band && !Solid(x, y); y--) cut[y * w + x] = true;
        }
        for (int y = 0; y < h; y++)
        {
            for (int x = 0; x < band && !Solid(x, y); x++) cut[y * w + x] = true;
            for (int x = w - 1; x >= w - band && !Solid(x, y); x--) cut[y * w + x] = true;
        }
        chips = cut;
        var rects = new List<int>();
        List<int> prev = null; int prevStart = 0;
        for (int y = 0; y <= h; y++)
        {
            List<int> runs = null;
            if (y < h)
            {
                runs = new List<int>();
                for (int x = 0; x < w;)
                {
                    while (x < w && cut[y * w + x]) x++;
                    int x0 = x;
                    while (x < w && !cut[y * w + x]) x++;
                    if (x > x0) { runs.Add(x0); runs.Add(x); }
                }
            }
            bool same = prev != null && runs != null && prev.Count == runs.Count;
            for (int i = 0; same && i < runs.Count; i++) same = prev[i] == runs[i];
            if (same) continue;
            if (prev != null)
                for (int i = 0; i < prev.Count; i += 2) rects.AddRange(new[] { prev[i], prevStart, prev[i + 1], y });
            prev = runs; prevStart = y;
        }
        int n = rects.Count / 4;
        var head = new[] { 32, 1, n, n * 16, 0, 0, w, h };
        var bytes = new byte[32 + n * 16];
        Buffer.BlockCopy(head, 0, bytes, 0, 32);
        Buffer.BlockCopy(rects.ToArray(), 0, bytes, 32, n * 16);
        var region = ExtCreateRegion(IntPtr.Zero, bytes.Length, bytes);
        if (region == IntPtr.Zero) { Log("форма окна не собралась: " + n + " прямоугольников"); return; }
        // Форма ставится после рисования: SetWindowRgn сам перерисовывает окно, внутри рисования — рано.
        BeginInvoke((Action)(() => { if (SetWindowRgn(Handle, region, true) == 0) Log("SetWindowRgn отказал"); }));
    }
}
