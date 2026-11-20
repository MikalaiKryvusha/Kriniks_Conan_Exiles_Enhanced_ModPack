// version_order.cs — the order of release numbers the launcher compares (KrinikConanVersion.cs; KUMM plans/55 phase E): 0.9.1-RC1 < 0.9.1-RC2 < … <
// 0.9.1-RC10 < 0.9.1 < 0.9.2-RC1; spellings that read the same; tags that are not our numbers. Every order case runs twice: against ReleaseNumber
// (each must hold) and against the launcher's OLD reading (System.Version with the tail after «-» cut, as Feed.ParseVersion read it until 2026-11-18) —
// the old reading must FAIL the RC cases, so the set is proven able to catch the defect it exists for.
//   csc -nologo -out:<dir>\version_order.exe _config\launcher\KrinikConanVersion.cs _config\launcher\test\version_order.cs && <dir>\version_order.exe
// Prints «PASS|FAIL <case>» per line; exit 0 — every new case passes AND the old reading fails at least one RC case. [NOT-TESTED]
using System;

static class VersionOrder
{
    static int failed;
    static void Check(bool ok, string what) { if (!ok) failed++; Console.WriteLine((ok ? "PASS " : "FAIL ") + what); }

    // The launcher's reading until 2026-11-18 (KrinikConanUpdates.cs Feed.ParseVersion, pack 9d2a8b4) — the named broken version.
    static Version Old(string text)
    {
        if (string.IsNullOrEmpty(text)) return null;
        int cut = text.IndexOfAny(new[] { '-', '+' });
        if (cut >= 0) text = text.Substring(0, cut);
        if (!Version.TryParse(text, out var v)) return null;
        return new Version(v.Major, v.Minor, Math.Max(0, v.Build));
    }

    static readonly string[][] LESS =
    {
        new[] { "0.9.1-RC1", "0.9.1-RC2" }, new[] { "0.9.1-RC2", "0.9.1" }, new[] { "0.9.1-RC9", "0.9.1-RC10" }, new[] { "0.9.1-RC1", "0.9.1" },
        new[] { "0.9.0", "0.9.1-RC1" }, new[] { "0.9.1", "0.9.2-RC1" }, new[] { "0.9.1-RC10", "0.9.1" }, new[] { "1.0.0", "1.0.1" }, new[] { "0.9.9", "0.10.0" },
    };
    static readonly string[][] SAME = { new[] { "1.0", "1.0.0" }, new[] { "0.9.1-rc1", "0.9.1-RC1" }, new[] { "0.9.1-RC.1", "0.9.1-RC1" }, new[] { "0.9.1+build5", "0.9.1" }, new[] { " 0.9.1-RC1 ", "0.9.1-RC1" } };
    static readonly string[] NOT_OURS = { "", null, "abc", "0.9.1-beta", "0.9.1-RC0", "0.9.1-RC", "0.9.1-RC99999999999", "v0.9.1", "0.9.1.2" };

    static int Main()
    {
        foreach (var p in LESS)
        {
            var a = ReleaseNumber.Parse(p[0]); var b = ReleaseNumber.Parse(p[1]);
            Check(a != null && b != null && a < b && b > a && a != b && !(a > b) && a.CompareTo(b) < 0, $"{p[0]} < {p[1]}");
        }
        foreach (var p in SAME)
        {
            var a = ReleaseNumber.Parse(p[0]); var b = ReleaseNumber.Parse(p[1]);
            Check(a != null && a == b && a.Equals(b) && a.GetHashCode() == b.GetHashCode() && a >= b && a <= b, $"«{p[0]}» = «{p[1]}»");
        }
        foreach (var t in NOT_OURS) Check(ReleaseNumber.Parse(t) == null, $"«{t ?? "null"}» is not a release number");
        Check(ReleaseNumber.Parse("0.9.1-rc1").ToString() == "0.9.1-RC1" && ReleaseNumber.Parse("1.0").ToString() == "1.0.0", "shown as 0.9.1-RC1 and 1.0.0");
        ReleaseNumber none = null;
        Check(none < ReleaseNumber.Parse("0.0.1") && none == null && !(none > ReleaseNumber.Parse("0.0.1")), "a missing number sorts below every number");

        int oldFails = 0;
        foreach (var p in LESS) { var a = Old(p[0]); var b = Old(p[1]); if (!(a != null && b != null && a < b)) oldFails++; }
        Check(oldFails > 0, $"control: the old reading fails {oldFails} of {LESS.Length} order cases (it must fail the RC ones)");

        Console.WriteLine(failed == 0 ? "ALL PASS" : failed + " FAILED");
        return failed == 0 ? 0 : 1;
    }
}
