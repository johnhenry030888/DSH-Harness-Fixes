import pathlib
import tempfile


def test_temporary_file_roundtrip():
    with tempfile.TemporaryFile() as handle:
        handle.write(b"ok")
        handle.flush()
        handle.seek(0)
        assert handle.read() == b"ok"


def test_mkstemp_and_mkdtemp():
    descriptor, path = tempfile.mkstemp(prefix="p21-")
    try:
        handle = __import__("os").fdopen(descriptor, "wb")
        try:
            handle.write(b"scratch")
        finally:
            handle.close()
        assert pathlib.Path(path).read_bytes() == b"scratch"
    finally:
        pathlib.Path(path).unlink(missing_ok=True)
    directory = tempfile.mkdtemp(prefix="p21-")
    try:
        probe = pathlib.Path(directory) / "probe.txt"
        probe.write_text("scratch")
        assert probe.read_text() == "scratch"
    finally:
        __import__("shutil").rmtree(directory, ignore_errors=True)


def test_tmp_is_dir():
    assert pathlib.Path("/tmp").is_dir()
