"""Run: python start.py, then open http://localhost:8000"""
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from functools import partial
import webbrowser
ROOT = Path(__file__).resolve().parent / 'site'
print('Книга: http://localhost:8000\nМастерская: http://localhost:8000/admin.html\nОстановка: Ctrl+C')
webbrowser.open('http://localhost:8000')
try:
    ThreadingHTTPServer(('127.0.0.1', 8000), partial(SimpleHTTPRequestHandler, directory=str(ROOT))).serve_forever()
except KeyboardInterrupt:
    print('\nКнига закрыта.')
