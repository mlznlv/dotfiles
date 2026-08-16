#!/usr/bin/env python3

"""Run a command with terminal stdin and answer its apply confirmation."""

import os
import select
import subprocess
import sys
import termios
import time


PROMPT = b"Apply this configuration? Type yes to continue:\n"


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: pty-confirm.py <answer|EOF> <command> [argument...]", file=sys.stderr)
        return 2

    answer = sys.argv[1]
    master, slave = os.openpty()
    attributes = termios.tcgetattr(slave)
    attributes[3] &= ~termios.ECHO
    termios.tcsetattr(slave, termios.TCSANOW, attributes)
    process = subprocess.Popen(
        sys.argv[2:],
        stdin=slave,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        env=os.environ.copy(),
        start_new_session=True,
    )
    os.close(slave)

    output = bytearray()
    deadline = time.monotonic() + 30
    assert process.stdout is not None
    while PROMPT not in output and process.poll() is None:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            process.terminate()
            process.wait()
            print("confirmation prompt timed out", file=sys.stderr)
            return 124
        ready, _, _ = select.select([process.stdout], [], [], min(remaining, 0.25))
        if ready:
            chunk = os.read(process.stdout.fileno(), 4096)
            if not chunk:
                break
            output.extend(chunk)

    if PROMPT in output:
        hook = os.environ.get("DOTFILES_PTY_CONFIRM_HOOK")
        if hook:
            hook_env = os.environ.copy()
            hook_env["DOTFILES_PTY_CHILD_PID"] = str(process.pid)
            hook_result = subprocess.run([hook], env=hook_env, check=False)
            if hook_result.returncode != 0:
                process.terminate()
                process.wait()
                print("confirmation hook failed", file=sys.stderr)
                return hook_result.returncode
            for _ in range(20):
                if process.poll() is not None:
                    break
                time.sleep(0.025)
        payload = b"\x04" if answer == "EOF" else answer.encode("utf-8") + b"\n"
        if process.poll() is None:
            os.write(master, payload)

    remainder, _ = process.communicate(timeout=30)
    output.extend(remainder)
    os.close(master)
    sys.stdout.buffer.write(output)
    if process.returncode < 0:
        return 128 + (-process.returncode)
    return process.returncode


if __name__ == "__main__":
    raise SystemExit(main())
