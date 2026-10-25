"""Summarize HC-SR04 bench captures; does not access hardware."""
import collections
import csv
import json
import statistics
import sys
from pathlib import Path

results = []
for filename in sys.argv[1:]:
    rows = list(csv.DictReader(Path(filename).open()))
    stamps = [int(r['trigger_monotonic_ns']) for r in rows if int(r['trigger_monotonic_ns']) > 0]
    intervals = [(b-a)/1e6 for a, b in zip(stamps, stamps[1:])]
    distances = [float(r['distance_cm']) for r in rows if r['status'] == 'ok']
    results.append(dict(file=filename, rows=len(rows), statuses=dict(collections.Counter(r['status'] for r in rows)),
        achieved_host_trigger_hz=((len(stamps)-1)*1e9/(stamps[-1]-stamps[0])) if len(stamps)>1 else None,
        interval_ms_min=min(intervals) if intervals else None,
        interval_ms_median=statistics.median(intervals) if intervals else None,
        interval_ms_max=max(intervals) if intervals else None,
        distance_cm_min=min(distances) if distances else None,
        distance_cm_median=statistics.median(distances) if distances else None,
        distance_cm_max=max(distances) if distances else None))
print(json.dumps(results, indent=2))
