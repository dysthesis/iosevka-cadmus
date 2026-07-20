"""Brief-exposure confusability instrument (RESEARCH.md §6B1).

Flashes a confusable token inside a short random carrier string, masks it,
and asks what you saw. Logs per-trial CSV and prints a per-set confusion
matrix; the per-glyph error *rate* is the decision signal (§6 Stage 4).

Run it in the deployed terminal at the deployed size — this script does no
font or size handling on purpose. Acclimatise >= 20 min before scoring a
new variant.

Usage: confusability.py [--exposure MS] [--trials N] [--sets A,B,...] [--selftest]
"""

import argparse
import csv
import random
import sys
import time
from datetime import date, datetime
from pathlib import Path

SETS = {
    "0Oo": ["0", "O", "o"],
    "1lI|": ["1", "l", "I", "|"],
    "rn/m": ["rn", "m"],
    "B8": ["B", "8"],
    "5S": ["5", "S"],
    "2Z": ["2", "Z"],
    "3E": ["3", "E"],
    "7T": ["7", "T"],
    "4A": ["4", "A"],
    "g9q": ["g", "9", "q"],
    "OQ": ["O", "Q"],
    ";:": [";", ":"],
    ",.": [",", "."],
    "~-": ["~", "-"],
    "`'\"": ["`", "'", '"'],
    "{}()[]<>": list("{}()[]<>"),
}

# Letters visually distant from every set member (no o l i g q m n r b s e z).
CARRIER = "achktuwx"
FIXATION_S = 0.5
ROW, COL = 8, 16
MASK = "▓"


def paint(text):
    sys.stdout.write(f"\033[2J\033[{ROW};{COL}H{text}")
    sys.stdout.flush()


def flush_input():
    # Drop anything typed during fixation/exposure so it cannot leak into input().
    try:
        import termios

        termios.tcflush(sys.stdin.fileno(), termios.TCIFLUSH)
    except Exception:
        pass


def run_trial(target, exposure_s, rng):
    stim = rng.choice(CARRIER) + target + rng.choice(CARRIER)
    paint("+")
    time.sleep(FIXATION_S)
    paint(stim)
    time.sleep(exposure_s)
    paint(MASK * len(stim))
    sys.stdout.write(f"\033[{ROW + 2};1H\033[?25h")
    flush_input()
    answer = input("between the outer letters? ").strip()
    sys.stdout.write("\033[?25l")
    return answer


def score(records):
    """records: iterable of (set_name, target, answer) -> {set: {(target, answer): n}}"""
    matrices = {}
    for set_name, target, answer in records:
        cell = matrices.setdefault(set_name, {})
        cell[(target, answer)] = cell.get((target, answer), 0) + 1
    return matrices


def error_rates(matrix):
    """{(target, answer): n} -> {target: (errors, total)}"""
    rates = {}
    for (target, answer), n in matrix.items():
        errors, total = rates.get(target, (0, 0))
        rates[target] = (errors + (n if answer != target else 0), total + n)
    return rates


def render(set_name, matrix):
    members = SETS[set_name]
    answered = members + sorted(
        {a for (_, a) in matrix} - set(members), key=lambda a: (len(a), a)
    )
    total = sum(matrix.values())
    errors = sum(n for (t, a), n in matrix.items() if a != t)
    width = max(2, *(len(a) for a in answered))
    lines = [f"{set_name}: {total} trials, {errors} errors ({errors / total:.0%})"]
    lines.append("  seen\\ans " + " ".join(f"{a:>{width}}" for a in answered))
    for target in members:
        row = [matrix.get((target, a), 0) for a in answered]
        if not any(row):
            continue
        lines.append(
            f"  {target:<8} " + " ".join(f"{n:>{width}}" for n in row)
        )
    rates = error_rates(matrix)
    lines.append(
        "  error rate: "
        + "  ".join(
            f"{t} {e}/{n}" for t, (e, n) in sorted(rates.items()) if n
        )
    )
    return "\n".join(lines)


def selftest():
    records = [
        ("B8", "B", "B"),
        ("B8", "B", "8"),
        ("B8", "8", "8"),
        ("B8", "8", "8"),
        ("0Oo", "O", "0"),
        ("rn/m", "rn", "m"),
        ("rn/m", "m", "m"),
    ]
    matrices = score(records)
    assert matrices["B8"] == {("B", "B"): 1, ("B", "8"): 1, ("8", "8"): 2}
    assert matrices["0Oo"] == {("O", "0"): 1}
    assert matrices["rn/m"] == {("rn", "m"): 1, ("m", "m"): 1}
    assert error_rates(matrices["B8"]) == {"B": (1, 2), "8": (0, 2)}
    assert error_rates(matrices["rn/m"]) == {"rn": (1, 1), "m": (0, 1)}
    out = render("B8", matrices["B8"])
    assert "4 trials, 1 errors (25%)" in out, out
    assert "B 1/2" in out, out
    out = render("rn/m", matrices["rn/m"])
    assert "rn 1/1" in out, out
    print("selftest ok")


def build_trials(set_names, per_set, rng):
    trials = []
    for name in set_names:
        members = SETS[name]
        # Balanced presentation so per-glyph rates get equal n.
        pool = members * (per_set // len(members))
        pool += rng.sample(members, per_set % len(members))
        trials += [(name, t) for t in pool]
    rng.shuffle(trials)
    return trials


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--exposure", type=int, default=200, metavar="MS")
    ap.add_argument("--trials", type=int, default=20, help="trials per set")
    ap.add_argument("--sets", help="comma-separated subset of: " + " ".join(SETS))
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()

    if args.selftest:
        selftest()
        return

    set_names = list(SETS)
    if args.sets:
        set_names = args.sets.split(",")
        unknown = [s for s in set_names if s not in SETS]
        if unknown:
            sys.exit(f"unknown sets {unknown}; valid: {list(SETS)}")

    if not (sys.stdin.isatty() and sys.stdout.isatty()):
        sys.exit("run interactively in the deployed terminal")

    rng = random.Random()
    trials = build_trials(set_names, args.trials, rng)

    csv_path = Path("artifacts") / f"confusability-{date.today().isoformat()}.csv"
    csv_path.parent.mkdir(exist_ok=True)
    new_file = not csv_path.exists()

    records = []
    sys.stdout.write("\033[?25l")
    try:
        with csv_path.open("a", newline="") as fh:
            writer = csv.writer(fh)
            if new_file:
                writer.writerow(["timestamp", "set", "target", "answer", "correct"])
            for set_name, target in trials:
                answer = run_trial(target, args.exposure / 1000, rng)
                records.append((set_name, target, answer))
                writer.writerow(
                    [
                        datetime.now().isoformat(timespec="seconds"),
                        set_name,
                        target,
                        answer,
                        int(answer == target),
                    ]
                )
                fh.flush()  # keep data on Ctrl-C
    except KeyboardInterrupt:
        pass
    finally:
        sys.stdout.write("\033[2J\033[H\033[?25h")
        sys.stdout.flush()

    if not records:
        return
    matrices = score(records)
    for set_name in set_names:
        if set_name in matrices:
            print(render(set_name, matrices[set_name]))
            print()
    print(f"{len(records)}/{len(trials)} trials logged to {csv_path}")


if __name__ == "__main__":
    main()
