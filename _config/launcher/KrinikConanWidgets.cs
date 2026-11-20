// KrinikConanWidgets — части окна по макетам KUIPS design/mockups.html (KUMM plans/57; макеты приняты владельцем 2026-11-18 15:03, строки — коммит пака
// 95f8b52): список состояния и полоса прогресса столбика, плашка обновлений, переключатель языка, выбор копии игры. Числа — логические пиксели
// макета (окно 960×540 при 100 %), на экране умножаются на масштаб окна (Metal.Zoom; HOUSE_RULES правило 17). Каждая часть рисует себя сама поверх
// картины окна: фон под ней — кэш окна (прозрачный фон WinForms), поэтому меняющиеся числа перерисовывают только её, а не картину 4K. [NOT-TESTED]
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Windows.Forms;

static class Look
{
    // Цифры: GDI+ не умеет включать табличные цифры шрифта (font-variant-numeric: tabular-nums макета), а у Segoe UI цифры табличные сами по себе —
    // меняющиеся числа строки не двигают (`[OWNER]` 2026-11-18 08:44 «чтобы НЕ ПРЫГАЛИ»). Поэтому строки состояния — Segoe UI, не Inter макета.
    public static readonly FontFamily Label = Family("Segoe UI Semibold", "Segoe UI"), Value = Family("Segoe UI", "Arial"), Serif = Family("Cambria", "Georgia");
    public static readonly ColorBlend GoldFace = Metal.GoldFace;

    public static FontFamily Family(string name, string fallback)
    {
        try { return new FontFamily(name); }
        catch (ArgumentException) { return new FontFamily(fallback); }
    }

    public static Color Rgba(int r, int g, int b, double a) => Color.FromArgb((int)Math.Round(a * 255), r, g, b);

    // Тень надписей .sh макета: 0 0 6px rgba(0,0,0,.85) и 0 1px 2px #000, поверх — буквы своими цветами.
    public static void Lettered(Graphics g, List<(GraphicsPath path, Color color)> runs, float s)
    {
        // Пустой текст даёт пустой контур, а GraphicsPath.AddPath на пустом контуре бросает ArgumentException («Недопустимый параметр»): стенд
        // 2026-11-18 15:42 — падение лаунчера в первые секунды на кадре экрана «notfound». Пустые контуры не рисуются. [NOT-TESTED]
        var drawn = runs.FindAll(r => r.path.PointCount > 0);
        if (drawn.Count == 0) return;
        runs = drawn;
        using (var all = new GraphicsPath())
        {
            foreach (var r in runs) all.AddPath(r.path, false);
            Lettering.Shadow(g, all, 0f, 0f, 6f * s, Color.FromArgb(217, 0, 0, 0));
            Lettering.Shadow(g, all, 0f, 1f * s, 2f * s, Color.Black);
        }
        g.SmoothingMode = SmoothingMode.AntiAlias;
        foreach (var r in runs) using (var b = new SolidBrush(r.color)) g.FillPath(b, r.path);
    }

    public static GraphicsPath Text(string text, FontFamily f, FontStyle style, float px, float x, float baseline, float spacing = 0f)
    {
        var p = new GraphicsPath();
        Lettering.Add(p, text, f, style, px, spacing, x, baseline);
        return p;
    }

    public static float Ascent(FontFamily f, FontStyle st) => (float)f.GetCellAscent(st) / f.GetEmHeight(st);
    public static float LineHeight(FontFamily f, FontStyle st) => (float)f.GetLineSpacing(st) / f.GetEmHeight(st);
}

// Столбик под главной кнопкой: список состояния (.st — точка · подпись · значение, значения на одной вертикали) или полоса прогресса (.prog — что
// делается, полоса с процентами, под ней тот же список чисел).
sealed class StatePanel : Control
{
    public sealed class Row
    {
        public string Label, Value;
        public bool Warn, Path;
        public Row(string label, string value, bool warn = false, bool path = false) { Label = label; Value = value; Warn = warn; Path = path; }
    }

    const float ROW_PX = 12f, ROW_LINE = 1.25f, ROW_GAP = 3f, DOT_W = 8f, COL_GAP = 6f, META_PX = 11.5f, META_TOP = 1f;
    const float WHAT_PX = 14.5f, BAR_H = 26f, BAR_RIM = 2f, BAR_CUT = 5f, PROG_GAP = 6f;
    static readonly Color LabelInk = Metal.Html("#f7ecd6"), ValueInk = Metal.Html("#e2d4ba"), WarnInk = Metal.Html("#ffcf8a"), Dot = Metal.Html("#f2b85a"),
                          WhatInk = Metal.Html("#f6e4bc"), PercentInk = Metal.Html("#fff4dc");

    public string What { get; private set; }
    public int Percent { get; private set; }
    public readonly List<Row> Rows = new List<Row>();

    // Строки раскладки: текст, шрифт, цвет, x, базовая линия — в пикселях экрана, считаются при Measure.
    readonly List<(string text, FontFamily font, Color color, float x, float baseline, float px)> lines = new List<(string, FontFamily, Color, float, float, float)>();
    float barTop, whatBase, scale = 1f;

    public StatePanel()
    {
        SetStyle(ControlStyles.SupportsTransparentBackColor | ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint |
                 ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
        BackColor = Color.Transparent;
    }

    public bool Empty => What == null && Rows.Count == 0;

    // true — изменилась форма списка (окно раскладывает столбик заново); при любом изменении содержимого панель перерисовывается сама: окно её не трогает,
    // если её границы остались прежними (судья 2026-11-20, круг 5, находка 1: «ожидание выпусков» → «нет связи» — то же число строк, та же высота, и
    // панель держала старый текст до сворачивания окна). Без изменений сам Set не раскладывает и не перерисовывает панель (HOUSE_RULES 41); раскладку
    // столбика окно делает своим Relayout. [NOT-TESTED]
    public bool Set(string what, int percent, IList<Row> rows)
    {
        bool shape = (what == null) != (What == null) || rows.Count != Rows.Count;
        for (int i = 0; !shape && i < rows.Count; i++) shape = rows[i].Label != Rows[i].Label || (rows[i].Value ?? "").Length / 24 != (Rows[i].Value ?? "").Length / 24;
        bool same = !shape && what == What && Math.Max(0, Math.Min(100, percent)) == Percent;
        for (int i = 0; same && i < rows.Count; i++) same = rows[i].Value == Rows[i].Value && rows[i].Warn == Rows[i].Warn && rows[i].Path == Rows[i].Path;
        if (same) return false;
        What = what; Percent = Math.Max(0, Math.Min(100, percent));
        Rows.Clear(); Rows.AddRange(rows);
        if (Width > 0) { if (!shape) Measure(Width, scale); Invalidate(); MetalWindow.PerfMark("StatePanel.Invalidate"); }
        return shape;
    }

    public string TextForLog()
    {
        var parts = new List<string>();
        if (What != null) parts.Add(What + " " + Percent + " %");
        foreach (var r in Rows) parts.Add(r.Label == null ? r.Value : r.Label + ": " + r.Value);
        return string.Join(" · ", parts);
    }

    // Раскладка в ширину столбика; возвращает высоту.
    public int Measure(int width, float s)
    {
        scale = s;
        lines.Clear();
        float y = 0;
        if (What != null)
        {
            float wpx = WHAT_PX * s;
            whatBase = y + wpx * Look.Ascent(Look.Serif, FontStyle.Bold);
            y += wpx * Look.LineHeight(Look.Serif, FontStyle.Bold) + PROG_GAP * s;
            barTop = y;
            y += BAR_H * s;
            if (Rows.Count > 0) y += PROG_GAP * s + META_TOP * s;
        }
        float px = (What != null ? META_PX : ROW_PX) * s, line = px * ROW_LINE, asc = px * Look.Ascent(Look.Value, FontStyle.Regular);
        float labelW = 0;
        foreach (var r in Rows) if (r.Label != null) labelW = Math.Max(labelW, Lettering.Advance(r.Label + ":", Look.Label, FontStyle.Regular, px));
        float dotX = 0, labelX = (DOT_W + COL_GAP) * s, valueX = labelX + labelW + COL_GAP * s;
        for (int i = 0; i < Rows.Count; i++)
        {
            var r = Rows[i];
            Color ink = r.Warn ? WarnInk : ValueInk;
            float x = r.Label == null ? labelX : valueX, max = width - x;
            var wrapped = Wrap(r.Value ?? "", px, max, r.Path);
            float baseline = y + (line - px * 1.2f) / 2 + asc;
            lines.Add(("•", Look.Value, Dot, dotX, baseline, px));
            if (r.Label != null) lines.Add((r.Label + ":", Look.Label, r.Warn ? WarnInk : LabelInk, labelX, baseline, px));
            foreach (var w in wrapped) { lines.Add((w, Look.Value, ink, x, baseline, px)); baseline += line; }
            y += wrapped.Count * line + (i < Rows.Count - 1 ? ROW_GAP * s : 0);
        }
        Height = (int)Math.Ceiling(y);
        return Height;
    }

    // Путь рвётся только после «\» (макет 15:1x: имя папки посреди слова не рвётся), остальное — по пробелам.
    static List<string> Wrap(string text, float px, float max, bool path)
    {
        Func<string, float> w = t => Lettering.Advance(t, Look.Value, FontStyle.Regular, px);
        var res = new List<string>();
        string rest = text;
        while (rest.Length > 0 && w(rest) > max)
        {
            int cut = -1;
            for (int i = rest.Length - 1; i > 0; i--)
                if ((path ? rest[i - 1] == '\\' : rest[i - 1] == ' ') && w(rest.Substring(0, i).TrimEnd()) <= max) { cut = i; break; }
            if (cut < 0) break;
            res.Add(rest.Substring(0, cut).TrimEnd());
            rest = rest.Substring(cut);
        }
        res.Add(rest);
        return res;
    }

    // Готовые строки списка: буквы с тенью (программное размытие — три прохода по каждому пикселю) рисуются один раз на строку и дальше копируются.
    // Ключ — всё, от чего строка зависит: текст, шрифт, цвет, место, кегль. При обновлении прогресса меняются две-три строки («Скачано», скорость,
    // время) — перерисовываются только они; строки, которых больше нет, уходят из кэша. До 2026-11-20 каждая перерисовка панели строила контуры и тени
    // всех строк заново: 19–33 мс на 300 % при каждом обновлении (баг 110; KUMM researches/efficient-code §0, §2.2). [NOT-TESTED]
    sealed class Glyphs { public Bitmap Image; public Point At; }
    readonly Dictionary<string, Glyphs> drawn = new Dictionary<string, Glyphs>();

    Glyphs Line(string text, FontFamily font, Color color, float x, float baseline, float px, float s)
    {
        string key = string.Join("\u0001", text, font.Name, color.ToArgb(), x, baseline, px, s);
        if (drawn.TryGetValue(key, out var ready)) return ready;
        Glyphs made = null;
        using (var p = Look.Text(text, font, FontStyle.Regular, px, x, baseline))
            if (p.PointCount > 0)
            {
                var b = p.GetBounds();
                int m = (int)Math.Ceiling(10 * s) + 4;   // размытие 6 px и сдвиг 1 px тени (Look.Lettered) с запасом
                int ax = (int)Math.Floor(b.X) - m, ay = (int)Math.Floor(b.Y) - m;
                var bmp = new Bitmap((int)Math.Ceiling(b.Right) + m - ax, (int)Math.Ceiling(b.Bottom) + m - ay, PixelFormat.Format32bppPArgb);
                using (var g = Graphics.FromImage(bmp))
                {
                    g.SmoothingMode = SmoothingMode.AntiAlias;
                    g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                    g.TranslateTransform(-ax, -ay);
                    Look.Lettered(g, new List<(GraphicsPath, Color)> { (p, color) }, s);
                }
                made = new Glyphs { Image = bmp, At = new Point(ax, ay) };
            }
        drawn[key] = made;
        return made;
    }

    protected override void OnPaint(PaintEventArgs e) { using (MetalWindow.Perf(MetalWindow.InPicture ? "StatePanel.Print" : "StatePanel.OnPaint")) PaintNow(e); }

    void PaintNow(PaintEventArgs e)
    {
        var g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        float s = scale;
        var used = new HashSet<Glyphs>();
        foreach (var l in lines)
        {
            var gl = Line(l.text, l.font, l.color, l.x, l.baseline, l.px, s);
            if (gl == null) continue;
            g.DrawImageUnscaled(gl.Image, gl.At);
            used.Add(gl);
        }
        var stale = new List<string>();
        foreach (var kv in drawn) if (kv.Value == null || !used.Contains(kv.Value)) stale.Add(kv.Key);
        foreach (var k in stale) { drawn[k]?.Image.Dispose(); drawn.Remove(k); }
        if (What == null) return;
        // «Что делается» — Cambria Bold, тень 1px 1px 0 #000 (.prog .what).
        using (var p = Look.Text(What, Look.Serif, FontStyle.Bold, WHAT_PX * s, 0, whatBase))
        {
            using (var sh = (GraphicsPath)p.Clone())
            using (var m = new Matrix())
            {
                m.Translate(s, s); sh.Transform(m);
                g.FillPath(Brushes.Black, sh);
            }
            using (var b = new SolidBrush(WhatInk)) g.FillPath(b, p);
        }
        DrawBar(g, new RectangleF(0, barTop, Width, BAR_H * s), s);
    }

    // Полоса (.bar): металлическая окантовка, тёмный жёлоб, золотая заливка как лицо «Играть», проценты по центру светлым с чёрной обводкой.
    void DrawBar(Graphics g, RectangleF r, float s)
    {
        using (var path = Metal.Chamfer(r, BAR_CUT * s))
        using (var brush = new LinearGradientBrush(RectangleF.Inflate(r, 0, 1), Color.Black, Color.Black, 90f) { InterpolationColors = Metal.Rim })
            g.FillPath(brush, path);
        var trough = RectangleF.Inflate(r, -BAR_RIM * s, -BAR_RIM * s);
        using (var brush = new LinearGradientBrush(RectangleF.Inflate(trough, 0, 1), Metal.Html("#0b0805"), Metal.Html("#1f170e"), 90f))
            g.FillRectangle(brush, trough);
        using (var pen = new Pen(Color.FromArgb(204, 0, 0, 0), 2f * s)) g.DrawLine(pen, trough.Left, trough.Top + s, trough.Right, trough.Top + s);
        if (Percent > 0)
        {
            var fill = new RectangleF(trough.X, trough.Y, trough.Width * Percent / 100f, trough.Height);
            using (var brush = new LinearGradientBrush(RectangleF.Inflate(fill, 0, 1), Color.Black, Color.Black, 90f) { InterpolationColors = Metal.GoldFace })
                g.FillRectangle(brush, fill);
            using (var pen = new Pen(Metal.Html("#fff3c9"), Math.Max(1f, s))) g.DrawLine(pen, fill.Left, fill.Top + pen.Width / 2, fill.Right, fill.Top + pen.Width / 2);
        }
        string text = Percent + " %";
        float px = WHAT_PX * s, w = Lettering.Advance(text, Look.Serif, FontStyle.Bold, px);
        float baseline = r.Top + (r.Height - px * Look.LineHeight(Look.Serif, FontStyle.Bold)) / 2 + px * Look.Ascent(Look.Serif, FontStyle.Bold);
        using (var p = Look.Text(text, Look.Serif, FontStyle.Bold, px, r.Left + (r.Width - w) / 2, baseline))
        {
            using (var pen = new Pen(Color.Black, 2.4f * s) { LineJoin = LineJoin.Round }) g.DrawPath(pen, p);
            using (var b = new SolidBrush(PercentInk)) g.FillPath(b, p);
        }
    }
}

// Плашка «Вышла сборка …» (.plate): слева под шапкой, 300 px, фон rgba(12,8,4,.74), кайма — те же полосы сырого металла, что у окна, по центру —
// строка и золотая «Обновить сборку» 220×40; ниже — то же для лаунчера, если вышел и он.
sealed class UpdatePlate : Control
{
    const float W = 300f, PAD_X = 18f, PAD_TOP = 15f, PAD_BOTTOM = 16f, GAP = 10f, TEXT_PX = 13f, TEXT_LINE = 1.35f, BUTTON_W = 220f, BUTTON_H = 40f, BUTTON_FONT = 17f, FRAME = 3f;
    static readonly Color TextInk = Metal.Html("#f2e6cf"), NumberInk = Metal.Html("#ffd27e");
    public readonly MetalButton BuildButton = new MetalButton { Gold = true, Spacing = 0, Cursor = Metal.Hand }, LauncherButton = new MetalButton { Gold = true, Spacing = 0, Cursor = Metal.Hand };
    public Bitmap FrameH, FrameV;
    string buildText, buildNumber, launcherText, launcherNumber;
    float scale = 1f, buildBase, launcherBase;

    public UpdatePlate()
    {
        SetStyle(ControlStyles.SupportsTransparentBackColor | ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint |
                 ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
        BackColor = Color.Transparent;
        Controls.Add(BuildButton);
        Controls.Add(LauncherButton);
        Visible = false;
    }

    // format с {0} — номер, его пишем золотом; null — этой строки нет.
    public void Set(string buildFormat, string buildNo, string launcherFormat, string launcherNo)
    {
        buildText = buildFormat; buildNumber = buildNo; launcherText = launcherFormat; launcherNumber = launcherNo;
        BuildButton.Visible = buildFormat != null;
        LauncherButton.Visible = launcherFormat != null;
        Visible = buildFormat != null || launcherFormat != null;
    }

    public void Arrange(float s)
    {
        scale = s;
        float y = PAD_TOP * s, px = TEXT_PX * s, line = px * TEXT_LINE, asc = px * Look.Ascent(Look.Value, FontStyle.Regular);
        int bw = (int)Math.Round(BUTTON_W * s), bh = (int)Math.Round(BUTTON_H * s), w = (int)Math.Round(W * s);
        foreach (var (text, button, isBuild) in new[] { (buildText, BuildButton, true), (launcherText, LauncherButton, false) })
        {
            if (text == null) continue;
            if (isBuild) buildBase = y + (line - px * 1.2f) / 2 + asc; else launcherBase = y + (line - px * 1.2f) / 2 + asc;
            y += line + GAP * s;
            button.Font = new Font("Georgia", BUTTON_FONT * s, FontStyle.Bold, GraphicsUnit.Pixel);
            button.Bounds = new Rectangle((w - bw) / 2, (int)Math.Round(y), bw, bh);
            y += bh + GAP * s;
        }
        Size = new Size(w, (int)Math.Ceiling(y - GAP * s + PAD_BOTTOM * s));
    }

    protected override void OnPaintBackground(PaintEventArgs e)
    {
        base.OnPaintBackground(e);
        var g = e.Graphics;
        using (var b = new SolidBrush(Look.Rgba(12, 8, 4, .74))) g.FillRectangle(b, ClientRectangle);
        int f = Math.Max(1, (int)Math.Round(FRAME * scale));
        if (FrameH != null && FrameV != null)
            using (var ia = new ImageAttributes())
            {
                ia.SetWrapMode(WrapMode.TileFlipXY);
                g.DrawImage(FrameV, new Rectangle(0, 0, f, Height), 0, 0, FrameV.Width, FrameV.Height, GraphicsUnit.Pixel, ia);
                g.DrawImage(FrameV, new Rectangle(Width - f, 0, f, Height), 0, 0, FrameV.Width, FrameV.Height, GraphicsUnit.Pixel, ia);
                g.DrawImage(FrameH, new Rectangle(0, 0, Width, f), 0, 0, FrameH.Width, FrameH.Height, GraphicsUnit.Pixel, ia);
                g.DrawImage(FrameH, new Rectangle(0, Height - f, Width, f), 0, 0, FrameH.Width, FrameH.Height, GraphicsUnit.Pixel, ia);
            }
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        var runs = new List<(GraphicsPath, Color)>();
        if (buildText != null) Line(runs, buildText, buildNumber, buildBase);
        if (launcherText != null) Line(runs, launcherText, launcherNumber, launcherBase);
        Look.Lettered(e.Graphics, runs, scale);
        foreach (var r in runs) r.Item1.Dispose();
    }

    // Строка по центру: часть до {0}, номер золотом, часть после; перенос не нужен — самая длинная строка короче плашки (проверено кадрами).
    void Line(List<(GraphicsPath, Color)> runs, string format, string number, float baseline)
    {
        float px = TEXT_PX * scale;
        int at = format.IndexOf("{0}", StringComparison.Ordinal);
        string head = at >= 0 ? format.Substring(0, at) : format, tail = at >= 0 ? format.Substring(at + 3) : "";
        string num = at >= 0 ? number : "";
        Func<string, FontStyle, float> w = (t, st) => Lettering.Advance(t, Look.Value, st, px);
        float total = w(head, FontStyle.Regular) + w(num, FontStyle.Bold) + w(tail, FontStyle.Regular), x = (Width - total) / 2;
        runs.Add((Look.Text(head, Look.Value, FontStyle.Regular, px, x, baseline), TextInk)); x += w(head, FontStyle.Regular);
        runs.Add((Look.Text(num, Look.Value, FontStyle.Bold, px, x, baseline), NumberInk)); x += w(num, FontStyle.Bold);
        runs.Add((Look.Text(tail, Look.Value, FontStyle.Regular, px, x, baseline), TextInk));
    }
}

// Выбор языка (.lang + .langlist макета, экран «language»): выпадающим списком, так как языков будет много (`[OWNER]` 2026-11-18 15:55, KUMM plans/57
// критерий 11). Закрытое поле — табличка высотой с кнопки окна: код текущего языка и стрелка вниз. Нажатие раскрывает под полем список поверх окна
// (правый край — по полю), каждый язык назван на нём самом, текущий отмечен золотой полосой слева; у открытого поля кант светлеет, стрелка смотрит
// вверх. Список закрывают выбор, повторное нажатие на поле, Esc, щелчок мимо и уход окна в фон. [NOT-TESTED]
sealed class LangSwitch : Control
{
    public const float H = 28f, PAD_L = 12f, PAD_R = 10f, GAP = 7f, CHEVRON = 10f, FONT = 13f, SPACING = .04f, RIM = 2.5f, LIST_TOP = 50f;
    public static readonly Ui.Lang[] Langs = (Ui.Lang[])Enum.GetValues(typeof(Ui.Lang));
    public event Action<Ui.Lang> Picked;
    public event Action Opened;
    public readonly LangList List;
    readonly ToolTip tip = new ToolTip();
    readonly OutsideClick outside;
    bool hover;

    public LangSwitch()
    {
        SetStyle(ControlStyles.SupportsTransparentBackColor | ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint |
                 ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
        SetStyle(ControlStyles.Selectable, false);
        BackColor = Color.Transparent;
        Cursor = Metal.Hand;
        AccessibleRole = AccessibleRole.ButtonDropDown;
        List = new LangList(this);
        outside = new OutsideClick(this);
    }

    public bool IsOpen => List.Visible;

    // Ширина — по самому широкому коду, чтобы поле не прыгало при смене языка.
    public static Size SizeAt(float s)
    {
        float code = 0;
        foreach (var l in Langs) code = Math.Max(code, Lettering.Width(Ui.Code(l).ToUpperInvariant(), Look.Serif, FontStyle.Bold, FONT * s, SPACING * FONT * s));
        return new Size((int)Math.Ceiling(2 * RIM * s + (PAD_L + GAP + CHEVRON + PAD_R) * s + code), (int)Math.Round(H * s));
    }

    // Имя для UI Automation у простого Control — текст его окна (AccessibleName она не читает: стенд 2026-11-18 15:5x, переключатель был безымянным).
    public void Retext()
    {
        tip.SetToolTip(this, Ui.T("caps.language")); AccessibleName = Text = Ui.T("caps.language");
        List.Retext();
        Invalidate();
    }

    public void Open()
    {
        if (IsOpen) return;
        List.Visible = true;
        List.BringToFront();
        Application.AddMessageFilter(outside);
        Invalidate();
        MetalWindow.Log("список языков открыт: " + List.TextForLog());
        Opened?.Invoke();
    }

    public void Close()
    {
        if (!IsOpen) return;
        Application.RemoveMessageFilter(outside);
        List.Visible = false;
        Invalidate();
        MetalWindow.Log("список языков закрыт");
    }

    public void Toggle() { if (IsOpen) Close(); else Open(); }

    // Выбор из списка: сначала список закрывается, потом язык меняется — окно перерисуется уже без списка.
    internal void Pick(Ui.Lang lang)
    {
        Close();
        Picked?.Invoke(lang);
    }

    protected override void OnMouseClick(MouseEventArgs e) { base.OnMouseClick(e); if (e.Button == MouseButtons.Left) Toggle(); }
    protected override void OnMouseEnter(EventArgs e) { base.OnMouseEnter(e); hover = true; Invalidate(); }
    protected override void OnMouseLeave(EventArgs e) { base.OnMouseLeave(e); hover = false; Invalidate(); }

    // Стенд: «щелчок» без мыши (BM_CLICK от click.ps1) раскрывает или закрывает список, как щелчок игрока.
    protected override void WndProc(ref Message m)
    {
        const int BM_CLICK = 0x00F5;
        if (m.Msg == BM_CLICK) { Toggle(); return; }
        base.WndProc(ref m);
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing) Application.RemoveMessageFilter(outside);
        base.Dispose(disposing);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        float s = Metal.Zoom(this);
        Color top = hover && !IsOpen ? Metal.Html("#56412b") : Metal.Html("#3b2e21"), bottom = hover && !IsOpen ? Metal.Html("#231910") : Metal.Html("#161009");
        var face = Metal.Plaque(g, new Rectangle(0, 0, Width, Height), s, IsOpen ? Metal.GoldFace : Metal.Rim, top, bottom);
        string code = Ui.Code(Ui.Current).ToUpperInvariant();
        float px = FONT * s, sp = SPACING * px, x = face.Left + PAD_L * s;
        float baseline = face.Top + (face.Height - px * Look.LineHeight(Look.Serif, FontStyle.Bold)) / 2 + px * Look.Ascent(Look.Serif, FontStyle.Bold);
        using (var p = Look.Text(code, Look.Serif, FontStyle.Bold, px, x, baseline, sp))
        {
            using (var sh = (GraphicsPath)p.Clone())
            using (var m = new Matrix()) { m.Translate(s, s); sh.Transform(m); g.FillPath(Brushes.Black, sh); }
            using (var b = new SolidBrush(Metal.Html("#f6e4bc"))) g.FillPath(b, p);
        }
        // Стрелка — путь макета в квадрате 10 px: вниз M1.5 3.5 5 7 8.5 3.5, у открытого — вверх M1.5 6.5 5 3 8.5 6.5; золото сверху вниз, как значки кнопок окна.
        float cx = face.Right - (PAD_R + CHEVRON) * s, cy = face.Top + (face.Height - CHEVRON * s) / 2;
        Func<float, float, PointF> at = (u, v) => new PointF(cx + u * s, cy + v * s);
        var pts = IsOpen ? new[] { at(1.5f, 6.5f), at(5f, 3f), at(8.5f, 6.5f) } : new[] { at(1.5f, 3.5f), at(5f, 7f), at(8.5f, 3.5f) };
        using (var glyph = new LinearGradientBrush(new RectangleF(cx, cy - 1, CHEVRON * s, CHEVRON * s + 2), Metal.Html("#fbe9b6"), Metal.Html("#c98a44"), 90f))
        using (var pen = new Pen(glyph, Math.Max(1.5f, 2.2f * s)) { StartCap = LineCap.Round, EndCap = LineCap.Round, LineJoin = LineJoin.Round })
            g.DrawLines(pen, pts);
    }

    // Щелчок мимо поля и списка и Esc закрывают список; сообщение идёт дальше своим путём (щелчок по кнопке окна остаётся щелчком). [NOT-TESTED]
    sealed class OutsideClick : IMessageFilter
    {
        const int WM_KEYDOWN = 0x0100, WM_LBUTTONDOWN = 0x0201, WM_RBUTTONDOWN = 0x0204, WM_MBUTTONDOWN = 0x0207, WM_NCLBUTTONDOWN = 0x00A1, WM_NCRBUTTONDOWN = 0x00A4;
        readonly LangSwitch owner;
        public OutsideClick(LangSwitch o) { owner = o; }

        public bool PreFilterMessage(ref Message m)
        {
            if (!owner.IsOpen) return false;
            if (m.Msg == WM_KEYDOWN && ((Keys)(int)m.WParam & Keys.KeyCode) == Keys.Escape) { owner.Close(); return true; }
            if (m.Msg != WM_LBUTTONDOWN && m.Msg != WM_RBUTTONDOWN && m.Msg != WM_MBUTTONDOWN && m.Msg != WM_NCLBUTTONDOWN && m.Msg != WM_NCRBUTTONDOWN) return false;
            var c = Control.FromHandle(m.HWnd);
            while (c != null && c != owner && c != owner.List) c = c.Parent;
            if (c == null) owner.Close();
            return false;
        }
    }
}

// Раскрытый список языков (.langlist): 176 px, кант тем же металлом, что у табличек, тёмное лицо, строки 8 · 14 px. Строки — отдельные элементы с
// именем языка: так их находит и нажимает стенд (click.ps1 по имени), как кнопки окна. Тень drop-shadow макета не перенесена: прозрачный край
// элемента WinForms показывает только картину окна, а не соседние части, и тень резала бы плашку версии лаунчера (KUMM HOUSE_RULES правило 23).
sealed class LangList : Control
{
    public const float W = 176f, RIM = 2.5f, CUT = 6f, PAD_Y = 4f, ITEM_PAD_Y = 8f, ITEM_PAD_X = 14f, NAME_PX = 14f, CODE_PX = 12f, LINE = 1.25f;
    readonly LangSwitch owner;
    readonly List<LangItem> items = new List<LangItem>();
    float scale = 1f;

    public LangList(LangSwitch o)
    {
        owner = o;
        SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
        SetStyle(ControlStyles.Selectable, false);
        BackColor = Metal.Html("#120d08");
        AccessibleRole = AccessibleRole.List;
        foreach (var l in LangSwitch.Langs) { var it = new LangItem(this, l); items.Add(it); Controls.Add(it); }
        Visible = false;
    }

    internal float Scale => scale;
    internal void Pick(Ui.Lang lang) => owner.Pick(lang);

    // У самого списка имени нет: имя «Язык окна» носит поле, и стенд (click.ps1 по имени, слева направо) нажимал бы список вместо поля.
    public void Retext() { foreach (var it in items) it.Retext(); }

    public string TextForLog() => string.Join(", ", items.ConvertAll(it => it.Text + (it.Lang == Ui.Current ? " (текущий)" : "")));   // ui-ok: the stand log reads it, the player never sees it

    public static float ItemH(float s) => (ITEM_PAD_Y * 2 + NAME_PX * LINE) * s;

    // Место — правым краем по полю, сверху на LIST_TOP логических пикселей окна.
    public void Arrange(float s, int fieldRight, int top)
    {
        scale = s;
        int w = (int)Math.Round(W * s), rim = (int)Math.Round(RIM * s), pad = (int)Math.Round(PAD_Y * s);
        float ih = ItemH(s);
        for (int i = 0; i < items.Count; i++)
            items[i].Bounds = new Rectangle(rim, rim + pad + (int)Math.Round(i * ih), w - 2 * rim, (int)Math.Round(ih));
        Bounds = new Rectangle(fieldRight - w, top, w, 2 * (rim + pad) + (int)Math.Round(items.Count * ih));
        Region?.Dispose();
        using (var path = Metal.Chamfer(new RectangleF(0, 0, Width, Height), CUT * s)) Region = new Region(path);
        Invalidate(true);
    }

    protected override void OnPaintBackground(PaintEventArgs e)
    {
        var g = e.Graphics;
        float s = scale;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        var outer = new RectangleF(0, 0, Width, Height);
        using (var path = Metal.Chamfer(outer, CUT * s))
        using (var brush = new LinearGradientBrush(RectangleF.Inflate(outer, 0, 1), Color.Black, Color.Black, 90f) { InterpolationColors = Metal.Rim })
            g.FillPath(brush, path);
        var face = RectangleF.Inflate(outer, -RIM * s, -RIM * s);
        using (var path = Metal.Chamfer(face, Math.Max(1f, 4.5f * s)))
        using (var brush = new LinearGradientBrush(RectangleF.Inflate(face, 0, 1), Metal.Html("#2c2218"), Metal.Html("#120d08"), 90f))
            g.FillPath(brush, path);
    }
}

// Строка списка: имя языка на нём самом слева, код справа; текущий язык — золотая полоса слева и светлый градиент (.item.on), под мышью — тот же
// градиент слабее.
sealed class LangItem : Control
{
    public readonly Ui.Lang Lang;
    readonly LangList list;
    bool hover;

    public LangItem(LangList l, Ui.Lang lang)
    {
        list = l; Lang = lang;
        SetStyle(ControlStyles.SupportsTransparentBackColor | ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint |
                 ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
        SetStyle(ControlStyles.Selectable, false);
        BackColor = Color.Transparent;
        Cursor = Metal.Hand;
        AccessibleRole = AccessibleRole.ListItem;
        Retext();
    }

    public void Retext() { AccessibleName = Text = Ui.T("lang.name." + Ui.Code(Lang)); Invalidate(); }

    protected override void OnMouseClick(MouseEventArgs e) { base.OnMouseClick(e); if (e.Button == MouseButtons.Left) list.Pick(Lang); }
    protected override void OnMouseEnter(EventArgs e) { base.OnMouseEnter(e); hover = true; Invalidate(); }
    protected override void OnMouseLeave(EventArgs e) { base.OnMouseLeave(e); hover = false; Invalidate(); }

    protected override void WndProc(ref Message m)
    {
        const int BM_CLICK = 0x00F5;
        if (m.Msg == BM_CLICK) { list.Pick(Lang); return; }
        base.WndProc(ref m);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        float s = list.Scale;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        bool on = Ui.Current == Lang;
        if (on || hover)
        {
            double a0 = on ? .26 : .14, a1 = on ? .08 : .04;
            using (var b = new LinearGradientBrush(new RectangleF(0, 0, Width, Height), Look.Rgba(242, 185, 90, a0), Look.Rgba(242, 185, 90, a1), 0f))
                g.FillRectangle(b, 0, 0, Width, Height);
        }
        if (on) using (var b = new SolidBrush(Metal.Html("#f2b85a"))) g.FillRectangle(b, 0, 0, 3 * s, Height);
        float npx = LangList.NAME_PX * s, cpx = LangList.CODE_PX * s, sp = SPACING_CODE * cpx;
        float nameBase = (Height - npx * Look.LineHeight(Fonts.Body, FontStyle.Regular)) / 2 + npx * Look.Ascent(Fonts.Body, FontStyle.Regular);
        using (var p = Look.Text(Text, Fonts.Body, FontStyle.Regular, npx, LangList.ITEM_PAD_X * s, nameBase))
        using (var b = new SolidBrush(on ? Metal.Html("#f7ecd6") : Metal.Html("#e2d4ba"))) g.FillPath(b, p);
        string code = Ui.Code(Lang).ToUpperInvariant();
        float cw = Lettering.Width(code, Look.Serif, FontStyle.Bold, cpx, sp);
        float codeBase = (Height - cpx * Look.LineHeight(Look.Serif, FontStyle.Bold)) / 2 + cpx * Look.Ascent(Look.Serif, FontStyle.Bold);
        using (var p = Look.Text(code, Look.Serif, FontStyle.Bold, cpx, Width - LangList.ITEM_PAD_X * s - cw, codeBase, sp))
        using (var b = new SolidBrush(Metal.Html("#b49a74"))) g.FillPath(b, p);
    }

    const float SPACING_CODE = .04f;
}

// Выбор копии игры (.modal): поверх лаунчера — затемнение и табличка 640 px со списком копий; копий может быть сколько угодно, список прокручивается
// (`[OWNER]` 2026-11-18 08:37). Под затемнением — картина окна в той минуте, когда выбор открылся (снимок окна): окно под ним не нажимается.
sealed class ChooserOverlay : Control
{
    const float W = 640f, RIM = 3f, CUT = 8f, PAD_X = 22f, PAD_Y = 18f, GAP = 10f, TITLE_PX = 21f, TEXT_PX = 13f, TEXT_LINE = 1.35f, LIST_H = 236f;
    const float BTN_H = 44f, OK_W = 210f, CANCEL_W = 150f, BTN_GAP = 10f, BTN_TOP = 4f;
    public readonly CopyList List = new CopyList();
    public readonly MetalButton Ok = new MetalButton { Gold = true, Spacing = 0, Cursor = Metal.Hand }, Cancel = new MetalButton { Cursor = Metal.Hand };
    Bitmap picture;
    RectangleF box;
    float scale = 1f, titleBase;
    readonly List<(string text, float baseline)> textLines = new List<(string, float)>();
    public string Title = "", Text2 = "";

    public ChooserOverlay()
    {
        SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
        Controls.Add(List);
        Controls.Add(Ok);
        Controls.Add(Cancel);
        Visible = false;
    }

    public void Open(Bitmap under) { picture?.Dispose(); picture = under; Visible = true; BringToFront(); }
    public void Close() { Visible = false; picture?.Dispose(); picture = null; }

    public void Arrange(Size client, float s)
    {
        scale = s;
        Bounds = new Rectangle(Point.Empty, client);
        float w = W * s, x = (client.Width - w) / 2, inner = w - 2 * (RIM + PAD_X) * s;
        float y = (RIM + PAD_Y) * s, tpx = TITLE_PX * s;
        titleBase = y + tpx * Look.Ascent(Look.Serif, FontStyle.Bold);
        y += tpx * 1.2f + GAP * s;
        float px = TEXT_PX * s, line = px * TEXT_LINE;
        textLines.Clear();
        foreach (var l in Lettering.Wrap(Text2, t => Lettering.Advance(t, Fonts.Body, FontStyle.Regular, px), inner))
        {
            textLines.Add((l, y + (line - px * 1.2f) / 2 + px * Look.Ascent(Fonts.Body, FontStyle.Regular)));
            y += line;
        }
        y += GAP * s;
        float listTop = y;
        y += LIST_H * s + GAP * s + BTN_TOP * s;
        float btnTop = y;
        y += BTN_H * s + PAD_Y * s + RIM * s;
        float h = y, top = (client.Height - h) / 2;
        box = new RectangleF(x, top, w, h);
        int left = (int)Math.Round(x + (RIM + PAD_X) * s);
        List.Bounds = new Rectangle(left, (int)Math.Round(top + listTop), (int)Math.Round(inner), (int)Math.Round(LIST_H * s));
        int okW = (int)Math.Round(OK_W * s), cW = (int)Math.Round(CANCEL_W * s), bh = (int)Math.Round(BTN_H * s), right = left + (int)Math.Round(inner);
        Ok.Bounds = new Rectangle(right - okW, (int)Math.Round(top + btnTop), okW, bh);
        Cancel.Bounds = new Rectangle(Ok.Left - (int)Math.Round(BTN_GAP * s) - cW, Ok.Top, cW, bh);
        foreach (var b in new[] { Ok, Cancel }) b.Font = new Font("Georgia", 18.7f * s, FontStyle.Bold, GraphicsUnit.Pixel);
        List.Zoom = s;
        Invalidate(true);
    }

    protected override void OnPaintBackground(PaintEventArgs e)
    {
        var g = e.Graphics;
        if (picture != null) g.DrawImage(picture, 0, 0, picture.Width, picture.Height);
        using (var b = new SolidBrush(Look.Rgba(6, 4, 2, .66))) g.FillRectangle(b, ClientRectangle);
        g.SmoothingMode = SmoothingMode.AntiAlias;
        float s = scale;
        using (var shadow = new SolidBrush(Look.Rgba(0, 0, 0, .45))) using (var sp = Metal.Chamfer(new RectangleF(box.X, box.Y + 12 * s, box.Width, box.Height), CUT * s)) g.FillPath(shadow, sp);
        using (var path = Metal.Chamfer(box, CUT * s))
        using (var brush = new LinearGradientBrush(RectangleF.Inflate(box, 0, 1), Color.Black, Color.Black, 90f) { InterpolationColors = Metal.Rim })
            g.FillPath(brush, path);
        var inner = RectangleF.Inflate(box, -RIM * s, -RIM * s);
        using (var path = Metal.Chamfer(inner, 6 * s))
        using (var brush = new LinearGradientBrush(RectangleF.Inflate(inner, 0, 1), Metal.Html("#2c2218"), Metal.Html("#120d08"), 90f))
            g.FillPath(brush, path);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        float s = scale, x = box.X + (RIM + PAD_X) * s;
        using (var p = Look.Text(Title, Look.Serif, FontStyle.Bold, TITLE_PX * s, x, box.Y + titleBase))
        {
            using (var sh = (GraphicsPath)p.Clone()) using (var m = new Matrix()) { m.Translate(s, s); sh.Transform(m); g.FillPath(Brushes.Black, sh); }
            using (var b = new SolidBrush(Metal.Html("#ffd27e"))) g.FillPath(b, p);
        }
        using (var b = new SolidBrush(Metal.Html("#e2d4ba")))
            foreach (var (text, baseline) in textLines)
                using (var p = Look.Text(text, Fonts.Body, FontStyle.Regular, TEXT_PX * s, x, box.Y + baseline)) g.FillPath(b, p);
    }
}

// Список копий игры: строка — кружок выбора, «Conan Exiles 3.1.1 · без модов» и путь; выбранная — золотой полосой слева; колесо мыши листает.
sealed class CopyList : Control
{
    const float PAD_Y = 9f, PAD_X = 12f, RADIO_COL = 26f, NAME_PX = 14.5f, PATH_PX = 12f, SB = 10f;
    public sealed class Item { public string Name, State, Path; }
    public readonly List<Item> Items = new List<Item>();
    public int Selected;
    public event Action Chosen;
    public float Zoom = 1f;
    int top;   // прокрутка, пиксели

    public CopyList()
    {
        SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.ResizeRedraw | ControlStyles.Selectable, true);
        // Фон списка — лицо таблички (#2c2218 → #120d08) под rgba(0,0,0,.35) макета, сведённое к одному цвету: список — своё окно, прозрачность ему не нужна.
        BackColor = Metal.Html("#150f0a");
        Cursor = Metal.Hand;
    }

    float RowH => (PAD_Y * 2 + NAME_PX * 1.25f + PATH_PX * 1.25f) * Zoom;
    int Content => (int)Math.Ceiling(RowH * Items.Count);

    public void Scroll(int pixels) { top = Math.Max(0, Math.Min(Math.Max(0, Content - Height), top + pixels)); Invalidate(); }

    protected override void OnMouseWheel(MouseEventArgs e) { Scroll(-e.Delta * (int)RowH / 120); base.OnMouseWheel(e); }
    protected override void OnMouseDown(MouseEventArgs e) { int i = (int)((e.Y + top) / RowH); if (i >= 0 && i < Items.Count) { Selected = i; Invalidate(); } Focus(); base.OnMouseDown(e); }
    protected override void OnMouseDoubleClick(MouseEventArgs e) { base.OnMouseDoubleClick(e); Chosen?.Invoke(); }
    protected override bool IsInputKey(Keys k) => k == Keys.Up || k == Keys.Down || base.IsInputKey(k);
    protected override void OnKeyDown(KeyEventArgs e)
    {
        if (e.KeyCode == Keys.Down && Selected < Items.Count - 1) Selected++;
        else if (e.KeyCode == Keys.Up && Selected > 0) Selected--;
        else if (e.KeyCode == Keys.Enter) { Chosen?.Invoke(); return; }
        else { base.OnKeyDown(e); return; }
        float y = Selected * RowH;
        if (y < top) top = (int)y; else if (y + RowH > top + Height) top = (int)(y + RowH - Height);
        Invalidate();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        float s = Zoom, rh = RowH;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        bool bar = Content > Height;
        float right = Width - (bar ? SB * s : 0);
        for (int i = 0; i < Items.Count; i++)
        {
            float y = i * rh - top;
            if (y > Height || y + rh < 0) continue;
            var it = Items[i];
            if (i == Selected)
            {
                using (var b = new LinearGradientBrush(new RectangleF(0, y, right, rh), Look.Rgba(242, 185, 90, .26), Look.Rgba(242, 185, 90, .08), 0f)) g.FillRectangle(b, 0, y, right, rh);
                using (var b = new SolidBrush(Metal.Html("#f2b85a"))) g.FillRectangle(b, 0, y, 3 * s, rh);
            }
            using (var pen = new Pen(Look.Rgba(201, 138, 68, .25), Math.Max(1f, s))) g.DrawLine(pen, 0, y + rh - 0.5f, right, y + rh - 0.5f);
            float cx = PAD_X * s + 6 * s, cy = y + PAD_Y * s + 3 * s + 6 * s;
            using (var pen = new Pen(Metal.Html("#d9a352"), 1.5f * s)) g.DrawEllipse(pen, cx - 6 * s, cy - 6 * s, 12 * s, 12 * s);
            if (i == Selected) using (var b = new SolidBrush(Metal.Html("#ffe7a8"))) g.FillEllipse(b, cx - 2.6f * s, cy - 2.6f * s, 5.2f * s, 5.2f * s);
            float x = (PAD_X + RADIO_COL) * s, npx = NAME_PX * s, ppx = PATH_PX * s;
            float nameBase = y + PAD_Y * s + npx * Look.Ascent(Look.Serif, FontStyle.Bold);
            using (var p = Look.Text(it.Name, Look.Serif, FontStyle.Bold, npx, x, nameBase)) using (var b = new SolidBrush(Metal.Html("#f6e4bc"))) g.FillPath(b, p);
            float nx = x + Lettering.Advance(it.Name, Look.Serif, FontStyle.Bold, npx);
            using (var p = Look.Text(" · " + it.State, Look.Serif, FontStyle.Regular, npx, nx, nameBase)) using (var b = new SolidBrush(Metal.Html("#d9bf94"))) g.FillPath(b, p);
            float pathBase = y + PAD_Y * s + npx * 1.25f + ppx * Look.Ascent(Fonts.Body, FontStyle.Regular);
            // Путь шире строки — видна его концовка за «…»: имя папки игры важнее начала пути, а обрезанное посреди слова место — шов (кадр 96 dpi, 15:5x).
            string shown = it.Path;
            float room = right - x - PAD_X * s;
            if (Lettering.Advance(shown, Fonts.Body, FontStyle.Regular, ppx) > room)
            {
                int cut = 0;
                while (cut < shown.Length - 1 && Lettering.Advance("…" + shown.Substring(cut), Fonts.Body, FontStyle.Regular, ppx) > room) cut++;
                int slash = shown.IndexOf('\\', cut);
                shown = "…" + shown.Substring(slash > 0 && slash < shown.Length - 1 ? slash : cut);
            }
            using (var p = Look.Text(shown, Fonts.Body, FontStyle.Regular, ppx, x, pathBase)) using (var b = new SolidBrush(Metal.Html("#cdbfa6"))) g.FillPath(b, p);
        }
        using (var pen = new Pen(Look.Rgba(201, 138, 68, .55), Math.Max(1f, s))) g.DrawRectangle(pen, 0, 0, Width - 1, Height - 1);
        if (bar)
        {
            float sx = right, th = Math.Max(20 * s, Height * (float)Height / Content), ty = (Height - th) * top / Math.Max(1, Content - Height);
            using (var b = new SolidBrush(Look.Rgba(0, 0, 0, .4))) g.FillRectangle(b, sx, 0, SB * s, Height);
            using (var b = new LinearGradientBrush(new RectangleF(sx, 0, SB * s, Height), Metal.Html("#d9a352"), Metal.Html("#8a5a2a"), 0f))
                g.FillRectangle(b, sx + 2 * s, ty + 2 * s, SB * s - 4 * s, th - 4 * s);
        }
    }
}
