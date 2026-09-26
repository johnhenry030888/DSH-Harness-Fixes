import os
import tempfile


def test_tempfile_round_trip():
    with tempfile.NamedTemporaryFile(mode="w", delete=True) as handle:
        handle.write("hello")
        handle.flush()
        with open(handle.name) as reader:
            assert reader.read() == "hello"


def test_mkstemp_and_mkdtemp():
    fd, path = tempfile.mkstemp()
    os.close(fd)
    directory = tempfile.mkdtemp()
    assert os.path.exists(path)
    assert os.path.isdir(directory)


def test_tmp_present():
    assert os.path.isdir("/tmp")
