#!/usr/bin/env python3

import uuid
import sys
import os
import argparse
from datetime import datetime

def create_file():
    # Set up argument parsing
    parser = argparse.ArgumentParser(description="Create trigger files for Posterizarr.")

    # Add an optional argument for the path, with your default fallback
    parser.add_argument(
        "-p", "--path",
        default="/posterizarr/watcher",
        help="Directory path to save the file (default: /posterizarr/watcher)"
    )

    # Catch all remaining positional arguments as key-value pairs
    parser.add_argument(
        "kv_pairs",
        nargs="*",
        help="Key-value pairs (e.g., arg_name1 arg_value1 arg_name2 arg_value2)"
    )

    args = parser.parse_args()

    # Validate that we have an even number of arguments (pairs) and at least one pair
    if len(args.kv_pairs) % 2 != 0 or len(args.kv_pairs) == 0:
        print("Error: Arguments must be provided in key-value pairs.")
        print("Usage: trigger.py [-p /custom/path] <key1> <val1> [<key2> <val2> ...]")
        sys.exit(1)

    # Ensure the output directory exists
    os.makedirs(args.path, exist_ok=True)

    # Generate unique identifiers
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S%f")[:17]
    unique_id = uuid.uuid4().hex[:6]

    # Safely construct the file path regardless of OS or trailing slashes
    filename = os.path.join(
        args.path,
        f"recently_added_{timestamp}_{unique_id}.posterizarr"
    )

    # Group the arguments into a list of tuples: [(key1, val1), (key2, val2), ...]
    pairs = [(args.kv_pairs[i], args.kv_pairs[i+1]) for i in range(0, len(args.kv_pairs), 2)]

    # Write the file
    with open(filename, "w") as f:
        for key, value in pairs:
            f.write(f"[{key}]: {value}\n")

    # Print terminal output
    print(f"File '{filename}' created with content:")
    for key, value in pairs:
        print(f"[{key}]: {value}")

if __name__ == "__main__":
    create_file()