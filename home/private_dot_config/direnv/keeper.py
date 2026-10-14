#!/usr/bin/env python3
import os
import sys
import time

def run_keeper():
    # Read secrets from stdin before forking.
    try:
        data = sys.stdin.buffer.read()
    except EOFError:
        return
    
    if not data:
        return

    # First fork to detach from the parent process
    if os.fork() > 0:
        sys.exit(0)

    os.setsid()

    # Second fork to ensure we aren't a session leader
    if os.fork() > 0:
        sys.exit(0)

    # Close all file descriptors except for what we might need (log on stderr)
    # We do this to avoid keeping pipes open that the parent (direnv) might be waiting on.
    # We keep stderr (2) open because it's redirected to a log file in direnvrc.
    max_fd = 1024  # Resource limit usually higher, but 1024 is safe for our needs
    try:
        import resource
        max_fd = resource.getrlimit(resource.RLIMIT_NOFILE)[1]
        if max_fd == resource.RLIM_INFINITY:
            max_fd = 1024
    except Exception:
        pass

    for fd in range(max_fd):
        if fd == 2:
            continue
        try:
            os.close(fd)
        except OSError:
            pass

    # Create an anonymous memory-backed file (RAM only).
    try:
        fd = os.memfd_create('op_cache', 0)
        os.write(fd, data)
        os.lseek(fd, 0, os.SEEK_SET)

        # Stay alive to keep the file descriptor open.
        while True:
            time.sleep(3600)
    except Exception as e:
        # Since we kept stderr open, we can print the error
        sys.stderr.write(f"Keeper error: {e}\n")
        sys.exit(1)

if __name__ == "__main__":
    run_keeper()
