"""Desktop shortcuts of the launcher: the launcher window, or the game directly (--play, for Steam)."""
from paths import ROOT
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(ROOT / 'launcher'))
try:
    import sotc_launcher_win as launcher  # noqa: E402
except ImportError as error:  # no Tkinter
    launcher = None
    REASON = str(error)

EXE = r'C:\Games\SotC\SotC.exe'
PORT = r'C:\Games\SotC'


@unittest.skipIf(launcher is None, 'launcher not importable')
class ShortcutTests(unittest.TestCase):
    def test_frozen_launcher(self):
        script = launcher._shortcut_script(False, True, EXE, PORT, None)
        self.assertIn(r"+'\Shadow of the Colossus.lnk'", script)
        self.assertIn(rf"$s.TargetPath='{EXE}';$s.WorkingDirectory='{PORT}';$s.IconLocation='{EXE},0';", script)
        self.assertNotIn('Arguments', script)
        self.assertTrue(script.endswith('$s.Save()'))

    def test_frozen_play(self):
        script = launcher._shortcut_script(True, True, EXE, PORT, r'C:\data\icon0.ico')
        self.assertIn(r"+'\Shadow of the Colossus (play).lnk'", script)
        self.assertIn(r"$s.IconLocation='C:\data\icon0.ico';", script)
        self.assertIn("$s.Arguments='--play';", script)

    def test_dev_play(self):
        port = Path('/src/sotc')
        script = launcher._shortcut_script(True, False, '/no/such/python.exe', port, None)
        launcher_script = port / 'launcher' / 'sotc_launcher_win.py'
        self.assertIn("$s.TargetPath='/no/such/python.exe';", script)
        self.assertIn(f"""$s.Arguments='"{launcher_script}" --play';""", script)
        self.assertIn(f"$s.IconLocation='{port / 'launcher' / 'sotc.ico'}';", script)

    def test_dev_launcher(self):
        port = Path('/src/sotc')
        script = launcher._shortcut_script(False, False, '/no/such/python.exe', port, None)
        self.assertIn(f"""$s.Arguments='"{port / 'launcher' / 'sotc_launcher_win.py'}"';""", script)

    def test_quotes_and_dollar_escaped(self):
        port = "C:\\Kevin's $HOME \u2019x"
        script = launcher._shortcut_script(True, True, port + '\\SotC.exe', port, None)
        self.assertIn("$s.WorkingDirectory='C:\\Kevin''s $HOME \u2019\u2019x';", script)
        self.assertNotIn('"', script)


@unittest.skipIf(launcher is None, 'launcher not importable')
class DesktopEntryTests(unittest.TestCase):
    """The Linux shortcut: a .desktop entry on the desktop and in the menu."""

    def test_launcher_entry(self):
        entry = launcher.desktop_entry('Shadow of the Colossus', '"/opt/SotC-x86_64.AppImage"',
                                       '/home/deck/.local/share/icons/sotc.png')
        self.assertTrue(entry.startswith('[Desktop Entry]\nType=Application\n'))
        self.assertIn('Name=Shadow of the Colossus\n', entry)
        self.assertIn('Exec="/opt/SotC-x86_64.AppImage"\n', entry)
        self.assertIn('Icon=/home/deck/.local/share/icons/sotc.png\n', entry)
        self.assertIn('Terminal=false\n', entry)
        self.assertIn('StartupWMClass=sotc\n', entry)
        self.assertTrue(entry.endswith('\n'))

    def test_play_entry(self):
        entry = launcher.desktop_entry('Shadow of the Colossus (play)', '"/opt/SotC-x86_64.AppImage" --play',
                                       'sotc')
        self.assertIn('Name=Shadow of the Colossus (play)\n', entry)
        self.assertIn('Exec="/opt/SotC-x86_64.AppImage" --play\n', entry)


@unittest.skipIf(launcher is None, 'launcher not importable')
class UserIniTests(unittest.TestCase):
    """sotc.ini of the data folder: the AppImage's mount is read-only, so the launcher keeps a copy."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.port, self.data = root / 'share', root / 'data'
        (self.port).mkdir()
        (self.port / 'sotc.ini').write_text('SOTC_MODES=af16\n', encoding='utf-8')
        patch = mock.patch.multiple(launcher, PORT_DIR=self.port, DATA_DIR=self.data)
        patch.start()
        self.addCleanup(patch.stop)
        self.addCleanup(self.tmp.cleanup)

    def test_copy_beside_read_only_package(self):
        self.data.mkdir()
        target = launcher.user_ini()
        self.assertEqual(target, self.data / 'sotc.ini')
        self.assertEqual(target.read_text(encoding='utf-8'), 'SOTC_MODES=af16\n')
        target.write_text('SOTC_MODES=fps60\n', encoding='utf-8')
        self.assertEqual(launcher.user_ini(), target)
        self.assertEqual(target.read_text(encoding='utf-8'), 'SOTC_MODES=fps60\n')

    def test_source_checkout_uses_the_package_file(self):
        with mock.patch.object(launcher, 'DATA_DIR', self.port):
            self.assertEqual(launcher.user_ini(), self.port / 'sotc.ini')


if __name__ == '__main__':
    unittest.main()
