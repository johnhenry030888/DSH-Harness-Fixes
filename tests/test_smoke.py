"""Smoke test - runs under pytest or plain python3."""


def test_smoke():
    assert 1 + 1 == 2


if __name__ == "__main__":
    test_smoke()
    print("smoke ok")
