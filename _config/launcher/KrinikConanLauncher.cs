// KrinikConanLauncher (до 2026-10-31 17:34 KrinikLauncher) — лаунчер сборки Krinik, первая, рабочая версия (KUMM idea 22). Слово владельца 2026-10-31 11:11: «пусть в поставке игры будет наш exe
// лаунчер на будущее, и пусть ОТЗЫВ в нем открывает красиво сообщение инструкцию для игрока, как и куда писать КРинику отзыв, и какую папку
// приложить» · 11:20 «сделаешь раздел со ссылками автора».
// Вид окна — слово владельца 2026-10-31 17:42: «я сказал в лаунчере на фоне наш волпейпер» · «без виндовского бордера и кнопок» ·
// «кастомная кнопка закрытия и сворачивания в стиле металла конана» · «бордер кастомный в стиле металла конана» ·
// 17:51 «В ЛАУНЧЕРЕ чистый волпейпер!» · «БЕЗ ЗАПЕЧЁННЫХ ЛОГОТИПОВ! ЛОГОТИПЫ САМИ СТАВИМ!».
// Раскладка и вид — УТВЕРЖДЁННЫЙ макет 11 (_config/launcher/mockups/mockups.html?v=11&play=7; KUMM idea 22, выбор 18:22 — «APPROVED 18:53»):
// 18:22 «2, путь к игре над кнопкой, название вверх, ссылки вниз слева, кнопки в колонке справа, автор сборки - убрать заголовок» ·
// 18:26 «гнопку играть - вниз, золотой» · 18:32 «затемнение под текстом ок верни» · 18:31 «для конан эксайлс - это центрировать» ·
// 18:37 «ровняй без учета для, для светлее но меньше» · 18:39 «игра: - убрать, просто путь» · 18:53 «7. утвержденооооооо» — кайма play 7.
// Поэтому: окно без рамки Windows; на всём окне — чистый волпейпер с затемнением сверху, снизу и справа (как ::before макета); логотипы,
// заголовок, путь к игре и ссылки нарисованы в картину окна; справа внизу — столбик «Отзыв», «Удалить сборку», путь к игре и золотая
// главная кнопка последней: «Установить сборку», пока сборка не стоит, и «Играть» после (интервью 028, 20:11); кайма — сырой металл 3 px из картинок res/frame_*.png с рваной внешней кромкой, сквозь
// сколы которой видно рабочий стол (форма окна — по непрозрачности каймы).
// Числа раскладки — логические пиксели макета (окно 960×540 при 100 %), Windows умножает их на свой масштаб (HOUSE_RULES правило 17);
// картинки — из исходников под 4K при 300 %, окно их только уменьшает; res/ делает make-res.py.
// Ссылки автора и версия сборки не вписаны руками: их кладёт сюда _config/release/build-docs.py из author_links.txt и modpack.json
// (файл BuildInfo.g.cs), один разбор на ридми и лаунчер; у ссылки в лаунчере — свой короткий текст («PlayGround», 18:30 «просто плейграунд»).
// Собирается компилятором C# из Visual Studio 2022 против .NET Framework 4.x — он встроен в Windows 10/11, игроку ставить нечего.
// [TESTED: 2026-10-31 · live window at 100 % (PrintWindow; window region read back with GetWindowRgn) and the same render code at
//  288 and 384 dpi (KRINIK_LAUNCHER_SNAPSHOT) compared with mockup 11 frame variant_11_play7.webp — layout, sizes, colours, centring,
//  «Отзыв» plaque open; a live window at 300 % was not possible: this session's display is 1920×1080 at 100 %]
// Нажатия кнопок (install.cmd, удаление, «Играть», «Собрать отчёт») — та же логика, что до перерисовки, кликами не прогонялась.
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
using System.Windows.Forms;

static class KrinikConanLauncher
{
    // Окно уважает масштаб Windows (у владельца ТВ на 300 %) и не растягивается картинкой — HOUSE_RULES §1 правило 17.
    [DllImport("user32.dll")] static extern bool SetProcessDpiAwarenessContext(IntPtr value);
    static readonly IntPtr PER_MONITOR_AWARE_V2 = new IntPtr(-4);

    // Надписи таблички «Отзыв»: светлый пергамент и золото металла, тёмная обводка у каждой буквы.
    static readonly Color Ink = Metal.Html("#f7ecd6");
    static readonly Color Muted = Metal.Html("#e4d6bd");
    static readonly Color Gold = Metal.Html("#f2c977");

    const string GAME_EXE = "ConanSandbox.exe";
    const string REPORT_CMD = "collect_report.cmd";
    const string INSTALL_CMD = "install.cmd";
    // Архив кладут в папку игры или рядом с ней (путеводитель, «Установка»): игру ищем в папке лаунчера и выше на столько уровней.
    const int GAME_SEARCH_LEVELS = 3;

    [STAThread]
    static void Main()
    {
        try { SetProcessDpiAwarenessContext(PER_MONITOR_AWARE_V2); } catch (EntryPointNotFoundException) { /* Windows старше 10 1703 */ }
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(BuildWindow());
    }

    static string Here => AppDomain.CurrentDomain.BaseDirectory;

    static string FindGame()
    {
        var dir = new DirectoryInfo(Here);
        for (int i = 0; dir != null && i <= GAME_SEARCH_LEVELS; i++, dir = dir.Parent)
        {
            var exe = Path.Combine(dir.FullName, GAME_EXE);
            if (File.Exists(exe)) return exe;
        }
        return null;
    }

    static OutlinedLabel Text(string text, float pt, FontStyle style, Color color, string family = "Segoe UI") => new OutlinedLabel
    {
        Text = text, AutoSize = true, ForeColor = color, Font = new Font(family, pt, style),
        Margin = new Padding(0, 0, 0, 2) // предел ширины ставит FitWidth при раскладке окна
    };

    static MetalButton BigButton(string text) => new MetalButton
    {
        Text = text, AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink, Font = new Font("Georgia", 14f, FontStyle.Bold),
        Padding = new Padding(18, 9, 18, 9), Margin = new Padding(0, 0, 0, 12), Cursor = Cursors.Hand
    };

    // Кнопка столбика: размер и шрифт в пикселях экрана ставит окно (MetalWindow.Relayout) по макету — 270×44, Georgia bold 18.7 px.
    static MetalButton ColumnButton(string text) => new MetalButton { Text = text, Cursor = Cursors.Hand };

    static Form BuildWindow()
    {
        var game = FindGame();
        var form = new MetalWindow
        {
            Text = $"Сборка модов Krinik Mod Pack {BuildInfo.PackVersion} для Conan Exiles Enhanced 3.0.1",
            // Заголовок — как в руководстве, без повторов (владелец 2026-10-31 17:21: «нахуя ты повторяешься????»); «для» — отдельно, мелко.
            Title = $"Сборка модов Krinik Mod Pack {BuildInfo.PackVersion}",
            GameName = "Conan Exiles Enhanced 3.0.1",
            // Путь к игре — голый, без «Игра:» (18:39 «игра: - убрать, просто путь»); не нашли — короткая строка, что сделать.
            GamePath = game != null ? Path.GetDirectoryName(game) : "Игра не найдена: сборку — в папку игры",
            Links = BuildInfo.AuthorLinks,
            StartPosition = FormStartPosition.CenterScreen
        };

        // «Установить сборку» — тот же установщик install.cmd, что лежит рядом с лаунчером в корне архива (одна логика установки, окно — лицо над ней).
        // Владелец 2026-10-31 17:37: «У нас же лаунчер будет, который ставит сборку в автоматическом режиме».
        var install = ColumnButton("Установить сборку");
        var feedback = ColumnButton("Отзыв");
        var uninstall = ColumnButton("Удалить сборку");
        // «Играть» — последняя и золотая (18:26 «гнопку играть - вниз, золотой»).
        var play = new MetalButton { Text = "Играть", Cursor = Cursors.Hand };
        var installCmd = Path.Combine(Here, INSTALL_CMD);
        // «Удалить сборку» — тот же деинсталлятор, что раскатка кладёт в корень игры (KUMM bugs/72): откат по журналу на то,
        // что было в игре до сборки. Владелец 2026-10-31 15:53: «или чтобы прямо из лаунчера можно было это сделать по кнопке удаления сборки».
        var uninstallCmd = game != null ? Path.Combine(Path.GetDirectoryName(game), BuildInfo.UninstallCmd) : null;
        var gamePath = form.GamePath;

        // Главная кнопка — по состоянию сборки (интервью KUMM 028, Q2, ответ 2026-10-31 20:11: «кнопки играть нет, пока сборка не
        // уставнолена, на ее месте золотая Установить сборку»; 19:57 — после установки «Установить сборку» не видна, столбик смыкается).
        // Признак «сборка стоит» — деинсталлятор в корне игры: его кладёт только раскатка сборки и убирает только откат.
        // Снимку — KRINIK_LAUNCHER_STATE=fresh|installed: состояние без игры на диске.
        // [TESTED: 2026-10-31 · KUMM testcases/reports/2026-10-31_conan-launcher-main-button-by-state.md — snapshots at 384 dpi (forced) and
        //  96 dpi (a fake game folder, real detection), a BM_CLICK on the gold «Установить сборку» → install.cmd wrote the uninstaller →
        //  the window swapped to «Играть» by itself (UI Automation tree read before and after)]
        Action applyState = () =>
        {
            var forced = Environment.GetEnvironmentVariable("KRINIK_LAUNCHER_STATE");
            bool installed = forced == "installed" || (forced != "fresh" && uninstallCmd != null && File.Exists(uninstallCmd));
            install.Enabled = File.Exists(installCmd) || forced == "fresh";
            play.Enabled = game != null || forced == "installed";
            uninstall.Enabled = installed;
            form.GamePath = installed || game == null ? gamePath : gamePath + " · сборка не установлена";
            // Не установлена — «Удалить сборку» нет вовсе (владелец 2026-10-31 20:43: «удалить сборку кнопка не нужна, пока сборка не установлена»).
            if (installed) form.SetColumn(new[] { feedback, uninstall }, play);
            else form.SetColumn(new[] { feedback }, install, MetalWindow.INSTALL_FONT);
        };
        applyState();

        // Установщик — консольное окно install.cmd; когда оно закрылось, лаунчер смотрит на игру снова: сборка встала — золотой становится «Играть».
        install.Click += (s, e) =>
        {
            var p = Process.Start(new ProcessStartInfo(installCmd) { WorkingDirectory = Here, UseShellExecute = true });
            if (p == null) return;
            p.EnableRaisingEvents = true;
            p.Exited += (s2, e2) => form.BeginInvoke(applyState);
        };
        uninstall.Click += (s, e) =>
        {
            var ask = MessageBox.Show(form, "Удалить сборку Krinik и вернуть игру в тот вид, в каком она была до установки сборки?\n\nЗакройте игру перед удалением.",
                                      "Удалить сборку", MessageBoxButtons.YesNo, MessageBoxIcon.Question, MessageBoxDefaultButton.Button2);
            if (ask != DialogResult.Yes) return;
            Process.Start(new ProcessStartInfo(uninstallCmd) { WorkingDirectory = Path.GetDirectoryName(uninstallCmd), UseShellExecute = true });
            form.Close();
        };
        play.Click += (s, e) => Process.Start(new ProcessStartInfo(game) { WorkingDirectory = Path.GetDirectoryName(game) });

        // «Отзыв»: инструкция игроку — как собрать отчёт, что приложить и куда писать (тот же порядок, что на втором листе путеводителя).
        // Это сообщение, поэтому — своя металлическая табличка, только пока открыто; картина вокруг остаётся чистой.
        // Табличка открывается слева от столбика кнопок, над ссылками автора — на неё и показывает последняя строка.
        var report = new ReportPlaque { Padding = new Padding(18, 14, 18, 14), Margin = Padding.Empty, Visible = false };
        report.Controls.Add(Text("Как прислать отзыв или отчёт о падении", 14f, FontStyle.Bold, Gold, "Georgia"));
        report.Controls.Add(Text("1. Нажмите «Собрать отчёт». Игру закрывать не обязательно.", 11f, FontStyle.Regular, Ink));
        report.Controls.Add(Text("2. Дождитесь строки «Готово»: на рабочем столе появится файл Conan-report-<дата>_<время>.zip.", 11f, FontStyle.Regular, Ink));
        report.Controls.Add(Text("3. Приложите этот файл к письму автору сборки и напишите, что происходило в игре перед падением.", 11f, FontStyle.Regular, Ink));
        report.Controls.Add(Text("Куда писать — ниже: почта и PlayGround автора. С вопросом по сборке пишите туда же, отчёт для этого не нужен.", 10f, FontStyle.Regular, Muted));
        var collect = BigButton("Собрать отчёт");
        collect.Margin = new Padding(0, 6, 0, 0);
        var reportCmd = Path.Combine(Here, REPORT_CMD);
        collect.Enabled = File.Exists(reportCmd);
        collect.Click += (s, e) => Process.Start(new ProcessStartInfo(reportCmd) { WorkingDirectory = Here, UseShellExecute = true });
        report.Controls.Add(collect);
        form.Aside = report;
        form.Controls.Add(report);
        feedback.Click += (s, e) => report.Visible = !report.Visible;
        form.DragBy(report);
        return form;
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
    public static float Advance(string text, FontFamily family, FontStyle style, float px)
    {
        if (string.IsNullOrEmpty(text)) return 0f;
        Measure.TextRenderingHint = TextRenderingHint.AntiAlias;
        using (var font = new Font(family, px, style, GraphicsUnit.Pixel))
            return Measure.MeasureString(text, font, PointF.Empty, Typo).Width;
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
        string rest = text;
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
        return lines;
    }
}

// Металл Конана: медь и золото букв логотипа (_config/branding/conan-exiles-enhanced-logo-3x.webp) и тёмное железо его таблички.
static class Metal
{
    public static Color Html(string hex) => ColorTranslator.FromHtml(hex);

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

    // То же с лицом из нескольких цветов и своим бликом по верхнему краю (золотая «Играть»: блик #fff3c9 во всю силу).
    public static RectangleF Plaque(Graphics g, Rectangle bounds, float scale, bool enabled, ColorBlend faceBlend, Color sheen)
    {
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        var outer = new RectangleF(bounds.X, bounds.Y, bounds.Width, bounds.Height);
        float rim = Math.Max(2f, 2.5f * scale), cut = Math.Max(3f, 6f * scale);
        using (var path = Chamfer(outer, cut))
        using (var brush = new LinearGradientBrush(RectangleF.Inflate(outer, 0, 1), Color.Black, Color.Black, 90f))
        {
            brush.InterpolationColors = enabled ? Rim : RimOff;
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

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        float dpi = g.DpiY, outline = Outline(dpi), scale = dpi / 96f;
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

    protected override void OnPaintBackground(PaintEventArgs e)
    {
        base.OnPaintBackground(e);
        Metal.Plaque(e.Graphics, new Rectangle(0, 0, Width, Height), Metal.Zoom(this), true,
                     Color.FromArgb(238, 0x2a, 0x21, 0x18), Color.FromArgb(238, 0x12, 0x0e, 0x0a));
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

    public MetalButton()
    {
        SetStyle(ControlStyles.SupportsTransparentBackColor | ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint |
                 ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
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
        float px = Font.Unit == GraphicsUnit.Pixel ? Font.Size : Font.SizeInPoints * DeviceDpi / 72f, spacing = GOLD_SPACING * px;
        float width = Lettering.Width(Text, Font.FontFamily, Font.Style, px, spacing);
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
        Cursor = Cursors.Hand;
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
    readonly CaptionButton minimize = new CaptionButton(false, "Свернуть"), close = new CaptionButton(true, "Закрыть");
    readonly ToolTip tips = new ToolTip();
    readonly List<List<Run>> blocks = new List<List<Run>>();
    readonly List<Run> links = new List<Run>();
    Bitmap cache;
    Size canvas;      // размер окна по раскладке; ClientSize Windows Forms урезает до размера экрана, картина — нет (нужно снимку)
    bool[] chips;     // сколы внешней кромки последней картины (true — не окно)
    MetalButton[] column;
    MetalButton play;
    Control aside;
    Rectangle logoGameRect, logoPackRect;
    int dpi = 96, hoverLink = -1;
    bool centered, layingOut;

    public string Title { get; set; } = "";
    public string GameName { get; set; } = "";
    public string GamePath { get; set; } = "";
    public BuildInfo.Link[] Links { get; set; } = new BuildInfo.Link[0];

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
        tips.SetToolTip(minimize, "Свернуть");
        tips.SetToolTip(close, "Закрыть");
        Controls.Add(minimize);
        Controls.Add(close);
    }

    static Bitmap Turned(Bitmap b)
    {
        if (b == null) return null;
        var t = (Bitmap)b.Clone();
        t.RotateFlip(RotateFlipType.Rotate180FlipNone);
        return t;
    }

    // Столбик справа внизу: кнопки сверху вниз, под ними путь к игре и последней — золотая главная («Играть» или «Установить сборку»).
    // Зовётся снова, когда сборку поставили: кнопки, которых нет в новом наборе, прячутся, столбик смыкается (владелец 2026-10-31 19:57).
    // mainFont — кегль главной в логических px: «Установить сборку» длиннее «Играть» и пишется мельче, чтобы влезть в строку (макет state=fresh, 22 px).
    readonly List<MetalButton> known = new List<MetalButton>();
    float mainFont = PLAY_FONT;

    public void SetColumn(MetalButton[] buttons, MetalButton mainButton, float mainFontPx = PLAY_FONT)
    {
        column = buttons;
        play = mainButton;
        mainFont = mainFontPx;
        foreach (var b in buttons) b.Gold = false;
        mainButton.Gold = true;
        var all = new List<MetalButton>(buttons) { mainButton };
        foreach (var b in all)
        {
            if (known.Contains(b)) continue;
            known.Add(b);
            Controls.Add(b);
            b.EnabledChanged += (s, e) => InvalidateCache();
        }
        foreach (var b in known) b.Visible = all.Contains(b);
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
            dpi = (int)((long)m.WParam & 0xFFFF);
            var r = (RECT)Marshal.PtrToStructure(m.LParam, typeof(RECT));
            Location = new Point(r.Left, r.Top);
            Relayout();
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
        Cursor = link >= 0 ? Cursors.Hand : Cursors.Default;
        if (link >= 0) Invalidate(links[link].Hit);
    }

    protected override void OnMouseClick(MouseEventArgs e)
    {
        base.OnMouseClick(e);
        int i = e.Button == MouseButtons.Left ? LinkAt(e.Location) : -1;
        if (i >= 0) Process.Start(new ProcessStartInfo(links[i].Url) { UseShellExecute = true });
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        try { int d = (int)GetDpiForWindow(Handle); dpi = d > 0 ? d : DeviceDpi; }
        catch (EntryPointNotFoundException) { dpi = DeviceDpi; } // Windows старше 10 1607
        if (Snapshot.dpi > 0) dpi = Snapshot.dpi;
    }

    protected override void OnLoad(EventArgs e)
    {
        base.OnLoad(e);
        Relayout();
        if (!centered) { CenterToScreen(); centered = true; }
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

    static (string, int, bool) ReadSnapshotVariable()
    {
        var v = Environment.GetEnvironmentVariable("KRINIK_LAUNCHER_SNAPSHOT");
        if (string.IsNullOrEmpty(v)) return (null, 0, false);
        var parts = v.Split(';');
        return (parts[0], parts.Length > 1 && int.TryParse(parts[1], out int d) ? d : 0, parts.Length > 2 && parts[2] == "report");
    }

    void SaveSnapshot(string file)
    {
        if (cache == null || cache.Size != canvas) Render();
        using (var shot = new Bitmap(canvas.Width, canvas.Height, PixelFormat.Format32bppArgb))
        {
            using (var g = Graphics.FromImage(shot)) g.DrawImage(cache, new Rectangle(Point.Empty, canvas), new Rectangle(Point.Empty, canvas), GraphicsUnit.Pixel);
            for (int i = Controls.Count - 1; i >= 0; i--) // снизу вверх: первый в Controls — верхний
            {
                var c = Controls[i];
                if (c.Visible && c.Width > 0 && c.Height > 0) c.DrawToBitmap(shot, c.Bounds);
            }
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

    // Раскладка макета 11 в пикселях экрана: заголовок сверху слева, столбик справа снизу вверх от «Играть», ссылки слева внизу;
    // раскрытый «Отзыв» — слева от столбика над ссылками; не влез между заголовком и ссылками — окно растёт вниз, картина его заполняет.
    void Relayout()
    {
        if (layingOut || play == null || !IsHandleCreated) return;
        layingOut = true;
        try
        {
            float s = Zoom;
            int w = Px(WIN_W), h = Px(WIN_H);
            foreach (var b in column) SetPixelFont(b, BUTTON_FONT * s);
            SetPixelFont(play, mainFont * s);
            foreach (var block in blocks) foreach (var run in block) run.Path.Dispose();
            blocks.Clear();
            links.Clear();
            hoverLink = -1;

            float titleBottom = LayoutTitle(s);
            int colW = Px(COL_W), colX = w - Px(COL_RIGHT) - colW;
            float pathPx = PATH_PX * s, pathLine = PATH_PX * INTER_LINE * s;
            var pathLines = Lettering.Wrap(GamePath, t => Lettering.Advance(t, Fonts.Body, FontStyle.Regular, pathPx), colW);
            float linksH = Links.Length * LINK_PX * LINK_LINE * s;

            if (aside != null) ScaleTree(aside, s);
            bool asideOn = aside != null && aside.Visible;
            if (asideOn)
            {
                KrinikConanLauncher.FitWidth(aside, colX - Px(ASIDE_GAP) - Px(LINKS_LEFT));
                float need = titleBottom + (ASIDE_BELOW_TITLE + ASIDE_ABOVE_LINKS + LINKS_BOTTOM) * s + aside.Height + linksH;
                if (need > h) h = (int)Math.Ceiling(need);
            }

            // Столбик — снизу вверх: «Играть», путь к игре, кнопки через COL_GAP.
            float y = h - (COL_BOTTOM + PLAY_H) * s;
            play.Bounds = new Rectangle(colX, (int)Math.Round(y), colW, Px(PLAY_H));
            y -= COL_GAP * s + pathLines.Count * pathLine;
            var pathBlock = new List<Run>();
            for (int i = 0; i < pathLines.Count; i++)
                pathBlock.Add(TextRun(pathLines[i], Fonts.Body, pathPx, 0f, colX, y + i * pathLine + PATH_PX * INTER_ASC * s, PathInk));
            blocks.Add(pathBlock);
            y -= (PATH_GAP + COL_GAP) * s;
            for (int i = column.Length - 1; i >= 0; i--)
            {
                y -= BUTTON_H * s;
                column[i].Bounds = new Rectangle(colX, (int)Math.Round(y), colW, Px(BUTTON_H));
                y -= COL_GAP * s;
            }

            float linksTop = h - LINKS_BOTTOM * s - linksH;
            LayoutLinks(linksTop, s);
            if (asideOn) aside.Location = new Point(Px(LINKS_LEFT), (int)Math.Round(linksTop - ASIDE_ABOVE_LINKS * s) - aside.Height);

            var size = new Size(Px(CAP_W), Px(CAP_H));
            close.Bounds = new Rectangle(w - Px(CAPS_RIGHT) - size.Width, Px(CAPS_TOP), size.Width, size.Height);
            minimize.Bounds = new Rectangle(close.Left - Px(CAPS_GAP) - size.Width, Px(CAPS_TOP), size.Width, size.Height);
            canvas = new Size(w, h);
            ClientSize = canvas;
            var area = Screen.FromControl(this).WorkingArea;
            if (Bottom > area.Bottom) Top = Math.Max(area.Top, area.Bottom - Height);
        }
        finally { layingOut = false; }
        InvalidateCache();
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

    static Run TextRun(string text, FontFamily family, float px, float spacing, float x, float baseline, Color color)
    {
        var path = new GraphicsPath();
        Lettering.Add(path, text, family, FontStyle.Regular, px, spacing, x, baseline);
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
        float dlyaW = Lettering.Width("для", Fonts.Small, FontStyle.Regular, dlyaPx, DLYA_SPACING * dlyaPx);
        float blockW = Math.Max(TITLE_INDENT * s + titleW, gameW);
        float titleBase = blockTop + (titleBox - TITLE_PX * OSWALD_LINE * s) / 2 + TITLE_PX * OSWALD_ASC * s;
        float gameTop = blockTop + titleBox + GAME_GAP * s, gameX = x + (blockW - gameW) / 2;
        float dlyaBottom = gameTop + gameBox - DLYA_RAISE * s;
        float dlyaBase = dlyaBottom - DLYA_PX * OSWALD_LINE * s + DLYA_PX * OSWALD_ASC * s;
        blocks.Add(new List<Run>
        {
            TextRun(Title, Fonts.Title, titlePx, TITLE_SPACING * titlePx, x + TITLE_INDENT * s, titleBase, TitleInk),
            TextRun(game, Fonts.GameName, gamePx, GAME_SPACING * gamePx, gameX, gameTop + GAME_PX * OSWALD_ASC * s, GameGold)
            // «для» убрано: владелец 2026-10-31 19:57 «из лаунчера для убираем» (было слева от названия игры с 18:37).
        });
        return top + rowH;
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
        blocks.Add(block);
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

    void Render()
    {
        cache?.Dispose();
        int w = canvas.Width, h = canvas.Height;
        cache = new Bitmap(w, h, PixelFormat.Format32bppPArgb);
        using (var g = Graphics.FromImage(cache))
        {
            g.Clear(BackColor);
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            // Смешение — как в браузере макета, в sRGB без гамма-коррекции: с HighQuality затемнение .82 выходит заметно светлее макета.
            g.CompositingQuality = CompositingQuality.AssumeLinear;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            DrawWallpaper(g, w, h);
            DrawShade(g, w, h);
            DrawImage(g, logoGame, logoGameRect);
            DrawImage(g, logoPack, logoPackRect);
            foreach (var block in blocks) DrawLettering(g, block);
            try { DrawFrame(g, w, h); }
            catch (Exception ex) when (ex is ArgumentException || ex is ExternalException || ex is InvalidOperationException) { Log("рамка не нарисовалась: " + ex); }
        }
    }

    // Журнал ошибок рисования — в %TEMP%\KrinikConanLauncher.log: окно должно открыться и без рамки, а причина — найтись.
    internal static void Log(string text)
    {
        try { File.AppendAllText(Path.Combine(Path.GetTempPath(), "KrinikConanLauncher.log"), DateTime.Now.ToString("s") + " " + text + Environment.NewLine); }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }
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
            foreach (var run in block) all.AddPath(run.Path, false);
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
