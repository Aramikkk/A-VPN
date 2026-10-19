import importlib.util
import io
import ipaddress
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).parent

def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

class AuditTests(unittest.TestCase):
    def test_domain_validation_and_idna(self):
        for name in ('gen_blocked_list', 'gen_rkn_domains'):
            mod = load(name)
            self.assertEqual(mod.normalize_domain('*.Пример.РФ'), 'xn--e1afmkfd.xn--p1ai')
            self.assertEqual(mod.normalize_domain('www.example.com'), 'example.com')
            for invalid in ('x' * 64 + '.ru', 'bad_name.ru', '# comment', 'x..ru', '\ud800.ru', 'a.ru; injection'):
                self.assertIsNone(mod.normalize_domain(invalid), invalid)

    def test_cidr_collapse_preserves_coverage_and_skips_invalid_lines(self):
        mod = load('gen_blocked_list')
        def fetch(path):
            return 'valid.ru\n' + 'x' * 64 + '.ru' if path == mod.DOMAINS else '10.1.0.0/25\n10.1.0.128/25\n10.1.0.0/26\nbroken\n'
        with tempfile.TemporaryDirectory() as temp:
            out = Path(temp) / 'lib/features/route_rules/notifier'
            out.mkdir(parents=True)
            with patch.object(mod, 'fetch', fetch):
                mod.main(temp)
            result = (out / 'blocked_list.dart').read_text(encoding='utf-8')
            self.assertIn("'10.1.0.0/24'", result)
            self.assertNotIn('/25', result)
            self.assertIn("'valid.ru'", result)

    def test_rkn_update_survives_invalid_domain(self):
        mod = load('gen_rkn_domains')
        with tempfile.TemporaryDirectory() as temp:
            out = Path(temp) / 'lib/features/route_rules/notifier'
            out.mkdir(parents=True)
            data = ('valid.ru\n' + 'x' * 64 + '.ru\nexample.com\n').encode()
            with patch.object(mod.urllib.request, 'urlopen', return_value=io.BytesIO(data)):
                mod.main(temp)
            result = (out / 'rkn_ru_domains.dart').read_text(encoding='utf-8')
            self.assertIn("'valid.ru'", result)
            self.assertNotIn('example.com', result)

    def test_release_build_number_must_increase(self):
        check = load('check_release_version').check_version
        self.assertEqual(check('version: 5.9.46+59046', [59044, 59045]), 59046)
        for value in ('version: 5.9.46+59045', 'version: 5.9.46+59000', 'version: 5.9.46'):
            with self.assertRaises(ValueError):
                check(value, [59045])

if __name__ == '__main__':
    unittest.main()
