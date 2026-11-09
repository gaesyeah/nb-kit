"""Paths and small helpers shared by the Python tests."""
import os
import subprocess
import sys

TESTS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(TESTS)
LIB = os.path.join(ROOT, 'lib')
sys.path[:0] = [LIB, os.path.join(LIB, 'themes')]
os.environ['NBKIT_LANG_FILES'] = os.path.join(ROOT, 'lang', 'en.lang')
os.environ['NBKIT_LANG'] = 'en'


def run(script, *args):
    """runs a lib/ Python script the way nbkit does; returns (exit code, stdout, stderr)"""
    env = dict(os.environ, PYTHONPATH=LIB)
    p = subprocess.run([sys.executable, os.path.join(LIB, script), *args], capture_output=True, text=True, env=env)
    return p.returncode, p.stdout, p.stderr


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)
