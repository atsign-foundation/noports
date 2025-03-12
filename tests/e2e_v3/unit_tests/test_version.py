import unittest as test

from lib.version import Version


class TestStringMethods(test.TestCase):
    def test_parse(self):
        version = Version("c:current")
        self.assertTrue(version.current)
        self.assertEqual(version.major, 999)
        self.assertEqual(version.minor, 999)
        self.assertEqual(version.patch, 999)

    pass


if __name__ == "__main__":
    _ = test.main()
