#!/usr/bin/env python3
"""
Ensures Touch ID is enabled for sudo by inserting 'auth sufficient pam_tid.so'
into /etc/pam.d/sudo if not already present.

Copyright (c) 2023 Paul Durivage
Modified by Sung for resilience and logging.
"""

import argparse
import pathlib
import re
import sys
from datetime import datetime

LINE = "\nauth       sufficient     pam_tid.so"
LOGFILE = "/var/log/pam_tid.log"

def log(msg):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    try:
        with open(LOGFILE, "a") as f:
            f.write(f"[{timestamp}] {msg}\n")
    except PermissionError:
        pass  # silently fail if we can't write to log

def main():
    parser = argparse.ArgumentParser(description="Ensures Touch ID is enabled for sudo")
    parser.add_argument("--check", action="store_true", help="Check if pam_tid.so is present")
    parser.add_argument("--file", type=str, default="/etc/pam.d/sudo", help="Target PAM file")
    parser.add_argument("--dry-run", action="store_true", help="Simulate changes without writing")
    args = parser.parse_args()

    path = pathlib.Path(args.file)

    if not path.exists() or not path.is_file():
        log(f"ERROR: {path} does not exist or is not a file")
        raise SystemExit(f"{path}: does not exist or is not a file")

    data = path.read_text()

    p_tid = re.compile(r'^auth\s+sufficient\s+pam_tid\.so$', flags=re.MULTILINE)
    match_tid = p_tid.search(data)

    if args.check:
        sys.exit(0 if match_tid else 1)

    if match_tid:
        log("pam_tid.so already present—no changes made")
        return

    p_auth_suff = re.compile(r"^auth\s+sufficient\s+pam_\w+\.so$", flags=re.MULTILINE)
    matches = list(p_auth_suff.finditer(data))

    if not matches:
        log("No suitable insertion point found—aborting")
        raise SystemExit("No suitable insertion point found")

    last_match = matches[-1]
    s_out = data[:last_match.end()] + LINE + data[last_match.end():]

    if args.dry_run:
        print(s_out)
        log("Dry run completed—no changes written")
        return

    path.write_text(s_out)
    log("pam_tid.so inserted successfully")

if __name__ == '__main__':
    main()

