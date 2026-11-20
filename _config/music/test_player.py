"""test_player.py — the stand of krinik_music_player.exe (KUMM plan 46), no game needed.

Builds a throwaway mod tree in the OS temp (music/combat: two 30 s tones, music/explore: one 4 s tone, music/combat_hard: empty), starts a stand-in
process for the game, runs the player against it (argv[2] = the stand-in's PID) and walks the cases P1..P7 by writing State/state.json the way the
Lua half will. Each case READS the result: the player's log, State/player.json, and the Windows audio session peak meter of the player process
(pycaw: a peak above zero = sound really leaves the process). Prints one line per case and exits 0 only when all pass.
    python test_player.py [<path to krinik_music_player.exe>]
NOT with `python -I`: isolated mode hides the user site-packages, pycaw fails to import, and the first version of this stand read that failure as
silence — P5/P6 «passed» on a meter that never ran (2026-11-06 17:51). A meter failure now raises.
[TESTED: 2026-11-06 · P0–P7 pass, peak 0.22 while playing (= volume 0.8 × tone 0.275), report testcases/reports/2026-11-06_conan-music-player-stand.md]
"""
import json, math, os, shutil, struct, subprocess, sys, tempfile, time, wave

HERE = os.path.dirname(os.path.abspath(__file__))
EXE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', '..', '_unpacked', 'KrinikConanMusic', 'player', 'krinik_music_player.exe')
RATE = 44100


def tone(path, hz, seconds):
    with wave.open(path, 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(RATE)
        frames = bytearray()
        for i in range(int(RATE * seconds)):
            v = int(9000 * math.sin(2 * math.pi * hz * i / RATE))
            frames += struct.pack('<hh', v, v)
        w.writeframes(bytes(frames))


def peak(pid):
    """The peak meter of the player's audio session (0..1), or 0.0 when the process has no session yet. A meter failure RAISES."""
    from pycaw.pycaw import AudioUtilities, IAudioMeterInformation
    for s in AudioUtilities.GetAllSessions():
        if s.ProcessId == pid:
            return s._ctl.QueryInterface(IAudioMeterInformation).GetPeakValue()
    return 0.0


def max_peak(pid, seconds):
    best = 0.0
    end = time.time() + seconds
    while time.time() < end:
        p = peak(pid)
        if isinstance(p, float):
            best = max(best, p)
        time.sleep(0.1)
    return best


root = tempfile.mkdtemp(prefix='kcm_stand_')
music, state = os.path.join(root, 'music'), os.path.join(root, 'State')
for d in ('combat', 'combat_hard', 'explore'):
    os.makedirs(os.path.join(music, d))
os.makedirs(state)
tone(os.path.join(music, 'combat', 'combat_a.wav'), 220, 30)
tone(os.path.join(music, 'combat', 'combat_b.wav'), 330, 30)
tone(os.path.join(music, 'explore', 'explore_x.wav'), 440, 4)

seq = [0]


def put(folders, active=True, volume=0.8, quit=False):
    seq[0] += 1
    body = json.dumps({'seq': seq[0], 'scene': folders[0] if folders else '', 'folders': folders, 'volume': volume, 'active': active, 'quit': quit})
    tmp = os.path.join(state, 'state.json.tmp')
    open(tmp, 'w', encoding='utf-8').write(body)
    os.replace(tmp, os.path.join(state, 'state.json'))


def log():
    p = os.path.join(state, 'player.log')
    return open(p, encoding='utf-8', errors='replace').read() if os.path.exists(p) else ''


def pj():
    try:
        return json.load(open(os.path.join(state, 'player.json'), encoding='utf-8'))
    except Exception:
        return {}


results = []


def case(name, ok, seen):
    results.append(ok)
    print('%s %s — %s' % (name, 'pass' if ok else 'FAIL', seen))


stand_in = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(600)'])
put([], active=False)
player = subprocess.Popen([EXE, root, str(stand_in.pid)])
try:
    time.sleep(1.5)
    case('P0', player.poll() is None and 'player started' in log(), 'player alive, log: %r' % log().strip().splitlines()[-1:])

    put(['combat_hard', 'combat'])
    time.sleep(1.2)
    j = pj()
    lp = max_peak(player.pid, 3.0)
    case('P1', j.get('playing') is True and j.get('folder') == 'combat' and 'combat' + os.sep in log().split('play ')[-1] and isinstance(lp, float) and lp > 0.01,
         'empty combat_hard -> combat: player.json folder=%s file=%s, inventory=%s, peak %.3f' % (j.get('folder'), j.get('file'), j.get('inventory'), lp))
    first = j.get('file')

    put(['explore'])
    time.sleep(1.0)
    j = pj()
    case('P2', j.get('folder') == 'explore', 'scene change -> explore: folder=%s (log tail %r)' % (j.get('folder'), log().strip().splitlines()[-2:]))

    time.sleep(6.0)  # the 4 s explore track ends -> the next track of the same folder starts
    plays = log().count('play ') ; ends_ok = log().count('explore_x.wav') >= 2
    case('P3', ends_ok, 'track end -> next track of the folder: explore_x started %d times' % log().count('explore_x.wav'))

    put(['combat'])
    time.sleep(1.0)
    j = pj()
    case('P4', 'resume combat' in log() and j.get('file') == first, 'combat re-entered within the grace period: resume=%s file=%s (first %s)' % ('resume combat' in log(), j.get('file'), first))

    put([])
    time.sleep(3.5)
    j = pj()
    lp = max_peak(player.pid, 1.5)
    case('P5', j.get('playing') is False and 'silence' in log() and isinstance(lp, float) and lp < 0.005,
         'empty chain -> silence: playing=%s, peak after the fade %.4f' % (j.get('playing'), lp))

    put(['combat'], volume=0.0)
    time.sleep(3.5)
    lp = max_peak(player.pid, 1.0)
    case('P6', isinstance(lp, float) and lp < 0.005, 'volume 0 (the game slider at zero) -> peak %.4f' % lp)

    stand_in.kill()
    t0 = time.time()
    while player.poll() is None and time.time() - t0 < 5:
        time.sleep(0.1)
    case('P7', player.poll() is not None and time.time() - t0 < 3 and 'the game ended' in log(), 'stand-in killed -> player exited in %.1f s' % (time.time() - t0))
finally:
    if player.poll() is None:
        player.kill()
    if stand_in.poll() is None:
        stand_in.kill()
    print('--- player.log ---')
    print(log())
    time.sleep(0.5)
    shutil.rmtree(root, ignore_errors=True)  # a temp tree this script made itself, by its own path
sys.exit(0 if all(results) else 1)
