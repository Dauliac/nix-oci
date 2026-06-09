"""Strip leading slashes from tar member paths, preserving all metadata.

Rewrites the tar archive in-place. Every file attribute (uid, gid, mode,
mtime, xattrs, symlink targets, hardlink targets, device nodes) is kept
intact -- only the member name and linkname are modified.

Handles both plain and gzip-compressed tar files, preserving the original
compression format.
"""

import sys
import tarfile
import io


def strip_leading_slash(path: str) -> str:
    stripped = path.lstrip("/")
    return stripped if stripped else "."


def detect_compression(path: str) -> str:
    with open(path, "rb") as f:
        magic = f.read(2)
    if magic == b"\x1f\x8b":
        return "gz"
    return ""


def rewrite_tar(path: str) -> None:
    compression = detect_compression(path)
    read_mode = f"r:{compression}"
    write_mode = f"w:{compression}"

    with open(path, "rb") as f:
        original = f.read()

    in_tar = tarfile.open(fileobj=io.BytesIO(original), mode=read_mode)
    buf = io.BytesIO()
    out_tar = tarfile.open(fileobj=buf, mode=write_mode, format=tarfile.PAX_FORMAT)

    for member in in_tar:
        member.name = strip_leading_slash(member.name)
        if member.linkname:
            member.linkname = strip_leading_slash(member.linkname)

        if member.isreg():
            fileobj = in_tar.extractfile(member)
            out_tar.addfile(member, fileobj)
        else:
            out_tar.addfile(member)

    out_tar.close()
    in_tar.close()

    with open(path, "wb") as f:
        f.write(buf.getvalue())


if __name__ == "__main__":
    rewrite_tar(sys.argv[1])
