#!/usr/bin/env python3

import sys
import tempfile
import subprocess

states = {
    0: "START",
    1: "R1",
    2: "R1C",
    3: "R1E",
    4: "R2",
    5: "R2C",
    6: "R2E",
    7: "R3",
    8: "R3C",
    9: "R3E",
   10: "WORK"
}

def main(argv0, *args):
    fh_in = sys.stdin
    fh_out = sys.stdout

    while True:
        l = fh_in.readline()
        if not l:
            return 0

        if "x" in l:
            fh_out.write(l)
            fh_out.flush()
            continue

        state = int(l, 16)
        if state in states:
          fh_out.write("%s\n" % states[state])
        else:
          fh_out.write(l)

        fh_out.flush()



if __name__ == '__main__':
  sys.exit(main(*sys.argv))