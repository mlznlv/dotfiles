#!/usr/bin/env python3

"""Drive exact line-oriented events through a command's terminal stdin."""

import json
import os
import select
import signal
import subprocess
import sys
import termios
import time


def wait_for_prompt(process: subprocess.Popen[bytes], output: bytearray, prompt: bytes) -> bool:
    deadline = time.monotonic() + 30
    assert process.stdout is not None
    while prompt not in output and process.poll() is None:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return False
        ready, _, _ = select.select([process.stdout], [], [], min(remaining, 0.25))
        if ready:
            chunk = os.read(process.stdout.fileno(), 4096)
            if not chunk:
                break
            output.extend(chunk)
    return prompt in output


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: pty-interactive.py <events-json> <command> [argument...]", file=sys.stderr)
        return 2

    try:
        events = json.loads(sys.argv[1])
    except (json.JSONDecodeError, TypeError):
        print("events must be a JSON array", file=sys.stderr)
        return 2
    if not isinstance(events, list):
        print("events must be a JSON array", file=sys.stderr)
        return 2

    master, slave = os.openpty()
    attributes = termios.tcgetattr(slave)
    attributes[3] &= ~termios.ECHO
    termios.tcsetattr(slave, termios.TCSANOW, attributes)
    process = subprocess.Popen(
        sys.argv[2:],
        stdin=slave,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=os.environ.copy(),
        start_new_session=True,
    )
    os.close(slave)

    output = bytearray()
    for index, event in enumerate(events):
        if not isinstance(event, dict) or not isinstance(event.get("wait"), str):
            process.terminate()
            process.wait()
            os.close(master)
            print("every event requires a string wait value", file=sys.stderr)
            return 2
        prompt = event["wait"].encode("utf-8")
        if not wait_for_prompt(process, output, prompt):
            if process.poll() is None:
                process.terminate()
                process.wait()
            os.close(master)
            sys.stdout.buffer.write(output)
            print(f"interactive prompt {index + 1} timed out", file=sys.stderr)
            return 124

        if event.get("hook"):
            hook = os.environ.get("DOTFILES_PTY_EVENT_HOOK")
            if not hook:
                process.terminate()
                process.wait()
                os.close(master)
                print("interactive event hook is unavailable", file=sys.stderr)
                return 2
            hook_env = os.environ.copy()
            hook_env["DOTFILES_PTY_CHILD_PID"] = str(process.pid)
            hook_env["DOTFILES_PTY_EVENT_INDEX"] = str(index)
            hook_result = subprocess.run([hook], env=hook_env, check=False)
            if hook_result.returncode != 0:
                process.terminate()
                process.wait()
                os.close(master)
                print("interactive event hook failed", file=sys.stderr)
                return hook_result.returncode

        if "signal" in event:
            signal_name = event["signal"]
            if signal_name not in {"HUP", "INT", "TERM"}:
                process.terminate()
                process.wait()
                os.close(master)
                print("unsupported interactive signal", file=sys.stderr)
                return 2
            os.killpg(process.pid, getattr(signal, f"SIG{signal_name}"))
        elif event.get("eof"):
            os.write(master, b"\x04")
        elif isinstance(event.get("send"), str):
            os.write(master, event["send"].encode("utf-8") + b"\n")
        else:
            process.terminate()
            process.wait()
            os.close(master)
            print("every event requires send, eof, or signal", file=sys.stderr)
            return 2

    try:
        remainder, error_output = process.communicate(timeout=30)
    except subprocess.TimeoutExpired:
        process.terminate()
        remainder, error_output = process.communicate()
        output.extend(remainder)
        os.close(master)
        sys.stdout.buffer.write(output)
        sys.stderr.buffer.write(error_output)
        print("interactive command timed out", file=sys.stderr)
        return 124

    output.extend(remainder)
    os.close(master)
    sys.stdout.buffer.write(output)
    sys.stderr.buffer.write(error_output)
    if process.returncode < 0:
        return 128 + (-process.returncode)
    return process.returncode


if __name__ == "__main__":
    raise SystemExit(main())
