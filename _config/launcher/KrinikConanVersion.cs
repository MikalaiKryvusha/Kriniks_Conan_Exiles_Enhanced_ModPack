// KrinikConanVersion — номер выпуска сборки или лаунчера: «0.9.1», «0.9.1-RC1» (KUMM plans/55, phase E).
// Порядок — классическое версионирование ПО (SemVer 2.0.0 §11; слово владельца 2026-11-18 19:09 «это классические правила версионирования ПО»):
// кандидат в выпуск стоит ниже своего выпуска, номер кандидата сравнивается как ЧИСЛО — 0.9.1-RC1 < 0.9.1-RC2 < … < 0.9.1-RC10 < 0.9.1 < 0.9.2-RC1.
// Запись кандидата — как у ядра Linux, без точки: «0.9.1-RC1» (слово владельца 19:11 «мы делаем как Линус, без точки»); «-rc1» и «-RC.1» читаются так же.
// Иной хвост после дефиса («-beta», «-hotfix») — не номер нашего выпуска: до 2026-11-18 хвост отбрасывался, и кандидат читался как окончательный
// выпуск (игрок с RC2 не увидел бы 0.9.1 обновлением). Такой тег лента теперь пропускает. «+…» (метаданные сборки) порядка не меняет.
// «1.0» и «1.0.0» — один номер. Файл ни от чего в лаунчере не зависит: test/version_order.cs собирается с ним одним.
// [TESTED: 2026-11-18 · version_order 26/26 + стенд self.mjs rc RC1–RC4 на собранном exe, контроль на прежнем exe FAIL · KUMM testcases/reports/2026-11-18_conan-launcher-rc-order.md]
using System;
using System.Globalization;
using System.Text.RegularExpressions;

sealed class ReleaseNumber : IComparable<ReleaseNumber>, IEquatable<ReleaseNumber>
{
    public readonly int Major, Minor, Patch;
    // Номер кандидата; 0 — окончательный выпуск. «-RC0» не номер: кандидаты считаются с единицы.
    public readonly int Rc;

    static readonly Regex FORM = new Regex(@"^(?<a>\d+)\.(?<b>\d+)(?:\.(?<c>\d+))?(?:-RC\.?(?<rc>\d+))?(?:\+[0-9A-Za-z.-]*)?$",
                                           RegexOptions.CultureInvariant | RegexOptions.IgnoreCase);

    ReleaseNumber(int major, int minor, int patch, int rc) { Major = major; Minor = minor; Patch = patch; Rc = rc; }

    public static ReleaseNumber Parse(string text)
    {
        if (string.IsNullOrWhiteSpace(text)) return null;
        var m = FORM.Match(text.Trim());
        if (!m.Success) return null;
        if (!Part(m, "a", out int a) || !Part(m, "b", out int b) || !Part(m, "c", out int c) || !Part(m, "rc", out int rc)) return null;
        if (m.Groups["rc"].Success && rc == 0) return null;
        return new ReleaseNumber(a, b, c, rc);
    }

    // Нет группы — 0; число шире int — не номер (а не исключение посреди ленты).
    static bool Part(Match m, string name, out int value)
    {
        value = 0;
        var g = m.Groups[name];
        return !g.Success || int.TryParse(g.Value, NumberStyles.None, CultureInfo.InvariantCulture, out value);
    }

    public int CompareTo(ReleaseNumber other)
    {
        if (other is null) return 1;
        int d = Major.CompareTo(other.Major);
        if (d == 0) d = Minor.CompareTo(other.Minor);
        if (d == 0) d = Patch.CompareTo(other.Patch);
        if (d != 0 || Rc == other.Rc) return d;
        if (Rc == 0) return 1;          // окончательный выпуск выше любого своего кандидата
        if (other.Rc == 0) return -1;
        return Rc.CompareTo(other.Rc);
    }

    public bool Equals(ReleaseNumber other) => !(other is null) && CompareTo(other) == 0;
    public override bool Equals(object obj) => Equals(obj as ReleaseNumber);
    public override int GetHashCode() => ((Major * 397 ^ Minor) * 397 ^ Patch) * 397 ^ Rc;
    public override string ToString() => Major + "." + Minor + "." + Patch + (Rc > 0 ? "-RC" + Rc : "");

    // null ниже любого номера, два null равны — так сравнения ленты не падают на теге без номера.
    static int Cmp(ReleaseNumber x, ReleaseNumber y) => x is null ? (y is null ? 0 : -1) : x.CompareTo(y);
    public static bool operator ==(ReleaseNumber x, ReleaseNumber y) => Cmp(x, y) == 0;
    public static bool operator !=(ReleaseNumber x, ReleaseNumber y) => Cmp(x, y) != 0;
    public static bool operator >(ReleaseNumber x, ReleaseNumber y) => Cmp(x, y) > 0;
    public static bool operator <(ReleaseNumber x, ReleaseNumber y) => Cmp(x, y) < 0;
    public static bool operator >=(ReleaseNumber x, ReleaseNumber y) => Cmp(x, y) >= 0;
    public static bool operator <=(ReleaseNumber x, ReleaseNumber y) => Cmp(x, y) <= 0;
}
