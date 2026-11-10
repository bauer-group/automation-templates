#!/usr/bin/env python3
"""Resolves the watched tag of Docker Base Image Monitor entries from a Dockerfile.

The monitor compares the digest behind <image>:<tag> with the one it stored.
With a fixed 'tag' in base-images.json the watched tag drifts away from the one
the image is built on as soon as Dependabot bumps the FROM line
(python:3.14-alpine -> python:3.15-alpine): Dependabot updates the Dockerfile,
never this config. The monitor then rebuilds whenever the unused tag moves and
misses every security rebuild of the real one. On 2026-11-10 eight repositories
drifted in one day, once auto-merge let tag bumps through on their own.

An entry with 'dockerfile' takes its tag from that Dockerfile's FROM line, so
the Dockerfile is the only place the tag is written down:

  {"name": "python", "image": "python", "dockerfile": "Dockerfile",
   "variable": "PYTHON_ALPINE_DIGEST"}

Resolved the way BuildKit does it for a build without --build-arg:

  * ARGs declared before the first FROM (the only ones a FROM line can use),
    including defaults that refer to earlier ARGs; $VAR, ${VAR}, ${VAR:-word},
    ${VAR-word}, ${VAR:+word} and ${VAR+word}. An ARG without a default is
    unset; one whose default uses such an ARG is an error wherever a FROM line
    uses it (BuildKit would expand the unset part to "", a guess here)
  * --platform=... flags, "AS <stage>", a digest pin (tag@sha256:...), a
    reference without a tag (= latest), and FROM lines that name an earlier
    stage rather than an image
  * comment lines, blank lines and backslash line continuations, also inside
    a continued instruction; a line ends at a line feed only (CRLF included)
  * heredocs of RUN, COPY and ADD (<<EOF, <<-EOF, <<'EOF'): the body is not an
    instruction, also where it holds a line like "from PIL import Image"

Which FROM line: the one whose image is 'image'. Several are fine as long as
they agree on the tag. 'stage' (the AS name) or 'from-index' (counted from 0,
as COPY --from=<n> counts stages) pick one explicitly. Without them, a FROM
line whose image or tag cannot be read fails the entry as well - it may use
'image' on another tag - unless its repository is written out as another
image. 'image' stays the cross-check: a FROM line of another image fails the
entry, it never silently changes what is monitored.

Entries without 'dockerfile' are passed through unchanged. An entry whose tag
cannot be read gets an ::error:: and is left out of the list - the monitor
never checks a guessed tag - and is listed as unresolved instead; so is an
entry with 'dockerfile' that shares its 'variable' with an entry checked on
another image:tag. The monitor checks every other image and fails the job at
the end, so one broken entry does not hold back the rebuilds of the rest.

Not resolved: --build-arg values given at build time (the ARG default is used)
and the '# escape=' parser directive.

Usage: resolve_base_images.py --output FILE [--root DIR] < images.json
  stdin   the monitor's image list (JSON array)
  stdout  log lines and workflow commands (::error::, ::notice::)
  FILE    {"images": [...], "unresolved": [...]} - the list with 'tag' set for
          every entry with 'dockerfile', without the entries that could not be
          resolved; those as {"name", "image", "dockerfile", "error"}
Exit code 0 once FILE is written, also with unresolved entries; 1 when the
input is not a JSON array.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import sys
from typing import Dict, List, NamedTuple, Optional, Tuple, Union

# Docker's grammar: a tag is up to 128 word characters, dots and dashes; a
# digest is <algorithm>:<hex>; repository path components are lower-case.
TAG_RE = re.compile(r"[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}")
DIGEST_RE = re.compile(r"[a-z0-9]+(?:[.+_-][a-z0-9]+)*:[0-9a-fA-F]{32,}")
COMPONENT_RE = re.compile(r"[a-z0-9]+(?:(?:[._]|__|-+)[a-z0-9]+)*")
DOMAIN_RE = re.compile(
    r"[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?"
    r"(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)*(?::[0-9]+)?"
)
NAME_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
INSTRUCTION_RE = re.compile(r"(\S+)\s*(.*)", re.S)
BRACED_RE = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)(?:(:?[-+])(.*))?", re.S)
# BuildKit accepts blanks after the continuation backslash.
CONTINUATION_RE = re.compile(r"\\[ \t]*$")
# A heredoc word as BuildKit reads it: [fd]<<[-]name, the name maybe quoted.
HEREDOC_RE = re.compile(r"(\d*)<<(-?)([^<]+)")
HEREDOC_INSTRUCTIONS = ("ADD", "COPY", "RUN")
DOCKER_HUB = "docker.io"


class ResolveError(Exception):
    """An entry whose tag cannot be taken from its Dockerfile."""

    def __init__(self, message: str, file: Optional[str] = None, line: Optional[int] = None):
        super().__init__(message)
        self.file = file
        self.line = line


class UndefinedArg(ResolveError):
    """A FROM line uses an ARG that has no value without --build-arg."""

    def __init__(self, name: str):
        super().__init__(
            f"${{{name}}} has no default value in the Dockerfile - it is a build argument "
            f"the monitor cannot see. Give 'ARG {name}' a default before the first FROM, "
            f"or write ${{{name}:-<default>}}"
        )
        self.name = name


# The ARGs before the first FROM: the value; None for an ARG without a default
# (unset in a build without --build-arg); the error for an ARG whose default
# cannot be read, raised wherever a FROM line uses it.
ArgValues = Dict[str, Union[str, None, ResolveError]]


class FromLine(NamedTuple):
    line: int                 # line of the FROM instruction, from 1
    index: int                # from 0, as COPY --from=<n> counts stages
    text: str                 # the image as written, before ARG expansion
    reference: Optional[str]  # the image after ARG expansion; None on error
    stage: Optional[str]      # the AS name, lower-case
    stage_ref: bool           # names an earlier stage, not an image
    error: Optional[str]      # why this line could not be resolved


class Resolved(NamedTuple):
    entry: dict
    tag: str
    line: int
    notices: List[Tuple[str, Optional[str], Optional[int]]]


# --- Dockerfile ---------------------------------------------------------------

def logical_lines(text: str) -> List[Tuple[int, str]]:
    """Instructions as (line of their first line, text).

    Continuation lines are joined the way BuildKit joins them - the backslash
    and the line break are removed, the next line follows as written. Comment
    and blank lines are dropped, also in the middle of a continued instruction.
    A line ends at a line feed, the carriage return of a CRLF dropped, as
    BuildKit reads it - not at a form feed or U+2028 inside a RUN, where
    str.splitlines() would start a new instruction. A heredoc body belongs to
    its instruction, up to the terminator line, as in BuildKit.
    """
    lines = [raw[:-1] if raw.endswith("\r") else raw for raw in text.split("\n")]
    result: List[Tuple[int, str]] = []
    parts: List[str] = []
    start = 0
    number = 0
    while number < len(lines):
        raw = lines[number]
        number += 1
        stripped = raw.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if not parts:
            start = number
        continuation = CONTINUATION_RE.search(raw)
        if continuation:
            parts.append(raw[:continuation.start()])
            continue
        parts.append(raw)
        instruction = "".join(parts).strip()
        result.append((start, instruction))
        parts = []
        for terminator, strip_tabs in _heredocs(instruction):
            while number < len(lines):
                body = lines[number]
                number += 1
                if (body.lstrip("\t") if strip_tabs else body) == terminator:
                    break
    if parts:
        result.append((start, "".join(parts).strip()))
    return result


def _heredocs(instruction: str) -> List[Tuple[str, bool]]:
    """The heredocs an instruction opens, in order, as (terminator, whether
    <<- strips leading tabs). Only RUN, COPY and ADD have them."""
    keyword, rest = INSTRUCTION_RE.fullmatch(instruction).groups()
    if keyword.upper() not in HEREDOC_INSTRUCTIONS or "<<" not in rest:
        return []
    try:
        # Quotes kept and a quoted string one word, as BuildKit splits the
        # line: the << of an exec form (RUN ["sh", "-c", "cat <<EOF"]) or of
        # sh -c "..." is inside a string, so it opens no heredoc.
        words = shlex.split(rest, posix=False)
    except ValueError:
        words = rest.split()
    found = []
    for word in words:
        match = HEREDOC_RE.fullmatch(word)
        if not match:
            continue
        try:
            name = shlex.split(match.group(3))
        except ValueError:
            continue
        if len(name) == 1:
            found.append((name[0], match.group(2) == "-"))
    return found


def expand(text: str, args: ArgValues) -> str:
    """Substitutes ARG values in text. An ARG declared without a default (and
    any name never declared) is unset, as in a build without --build-arg."""
    out: List[str] = []
    i = 0
    while i < len(text):
        char = text[i]
        if char == "\\" and text.startswith("$", i + 1):
            out.append("$")
            i += 2
        elif char != "$":
            out.append(char)
            i += 1
        elif text.startswith("{", i + 1):
            end = _closing_brace(text, i + 1)
            out.append(_expand_braced(text[i + 2:end], args))
            i = end + 1
        else:
            name = NAME_RE.match(text, i + 1)
            if name:
                out.append(_value(name.group(), args))
                i = name.end()
            else:
                out.append(char)
                i += 1
    return "".join(out)


def _closing_brace(text: str, opening: int) -> int:
    depth = 0
    for j in range(opening, len(text)):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                return j
    raise ResolveError(f"unterminated '${{' in '{text}'")


def _expand_braced(body: str, args: ArgValues) -> str:
    match = BRACED_RE.fullmatch(body)
    if not match:
        raise ResolveError(f"unsupported variable expansion '${{{body}}}'")
    name, operator, word = match.groups()
    value = _lookup(name, args)
    if operator is None:
        return _value(name, args)
    if operator == ":-":
        return value if value else expand(word, args)
    if operator == "-":
        return value if value is not None else expand(word, args)
    if operator == ":+":
        return expand(word, args) if value else ""
    return expand(word, args) if value is not None else ""  # "+"


def _lookup(name: str, args: ArgValues) -> Optional[str]:
    value = args.get(name)
    if isinstance(value, ResolveError):
        raise ResolveError(str(value))
    return value


def _value(name: str, args: ArgValues) -> str:
    value = _lookup(name, args)
    if value is None:
        raise UndefinedArg(name)
    return value


def _arg_words(rest: str) -> List[str]:
    try:
        return shlex.split(rest)
    except ValueError:
        return rest.split()


def parse_dockerfile(text: str) -> List[FromLine]:
    """Every FROM instruction of a Dockerfile, its image resolved."""
    args: ArgValues = {}
    froms: List[FromLine] = []
    stages = set()
    for number, instruction in logical_lines(text.lstrip("﻿")):
        keyword, rest = INSTRUCTION_RE.fullmatch(instruction).groups()
        keyword = keyword.upper()
        if keyword == "ARG" and not froms:
            for word in _arg_words(rest):
                name, has_default, default = word.partition("=")
                if not NAME_RE.fullmatch(name):
                    continue
                if not has_default:
                    args.setdefault(name, None)
                    continue
                try:
                    args[name] = expand(default, args)
                except ResolveError as exc:
                    # BuildKit expands an unset ARG in a default to "", which
                    # would be a guess here (ARG V=3.${U} is "3.", not unset).
                    # An error only for the FROM lines that use it.
                    args[name] = ResolveError(f"the default of 'ARG {word}' cannot be read: {exc}")
        elif keyword == "FROM":
            line = _parse_from(rest, number, len(froms), args, stages)
            froms.append(line)
            if line.stage:
                stages.add(line.stage)
    return froms


def _parse_from(rest: str, number: int, index: int, args: ArgValues, stages: set) -> FromLine:
    words = rest.split()
    while words and words[0].startswith("--"):
        words.pop(0)
    if len(words) == 1:
        text, stage = words[0], None
    elif len(words) == 3 and words[1].lower() == "as":
        text, stage = words[0], words[2].lower()
    else:
        return FromLine(number, index, rest, None, None, False, f"cannot parse 'FROM {rest}'")
    try:
        reference = expand(text, args)
    except ResolveError as exc:
        return FromLine(number, index, text, None, stage, False, str(exc))
    return FromLine(number, index, text, reference, stage, reference.lower() in stages, None)


# --- image references ---------------------------------------------------------

def split_reference(reference: str) -> Tuple[str, Optional[str], Optional[str]]:
    """(repository, tag, digest) of an image reference; tag and digest may be None."""
    name, _, digest = reference.partition("@")
    tag = None
    colon = name.rfind(":")
    if colon > name.rfind("/"):
        name, tag = name[:colon], name[colon + 1:]
    return name, tag, digest or None


def normalize_repository(name: str) -> Optional[str]:
    """The repository as Docker resolves it, None if it is not a valid name:
    python -> docker.io/library/python, index.docker.io/a/b -> docker.io/a/b."""
    first, slash, rest = name.partition("/")
    if slash and ("." in first or ":" in first or first == "localhost" or first != first.lower()):
        domain, path = first.lower(), rest
    else:
        domain, path = DOCKER_HUB, name
    if domain == "index.docker.io":
        domain = DOCKER_HUB
    components = path.split("/")
    if not DOMAIN_RE.fullmatch(domain) or not all(COMPONENT_RE.fullmatch(c) for c in components):
        return None
    if domain == DOCKER_HUB and len(components) == 1:
        path = f"library/{path}"
    return f"{domain}/{path}"


# --- entries ------------------------------------------------------------------

def read_dockerfile(root: str, path: str) -> str:
    if os.path.isabs(path) or path.startswith(("/", "\\")) or re.match(r"[A-Za-z]:", path):
        raise ResolveError(f"'dockerfile' must be relative to the repository root, got '{path}'")
    base = os.path.realpath(root)
    full = os.path.realpath(os.path.join(base, path))
    try:
        inside = os.path.commonpath([base, full]) == base
    except ValueError:
        inside = False
    if not inside:
        raise ResolveError(f"'dockerfile' {path} points outside the repository")
    if not os.path.isfile(full):
        raise ResolveError(f"Dockerfile not found: {path} (relative to the repository root)")
    with open(full, encoding="utf-8", errors="replace") as handle:
        return handle.read()


def _written_repository(text: str) -> Optional[str]:
    """The repository of a FROM line's image as written, normalized; None when
    an ARG hides it or the line could not be parsed (then it has blanks)."""
    if not text or any(char.isspace() for char in text):
        return None
    name = split_reference(text)[0]
    return None if "$" in name else normalize_repository(name)


def _describe(froms: List[FromLine]) -> str:
    def one(f: FromLine) -> str:
        if f.error:
            return f"line {f.line}: {f.text} ({f.error})"
        if f.stage_ref:
            return f"line {f.line}: {f.reference} (an earlier stage)"
        return f"line {f.line}: {f.reference}"
    return "; ".join(one(f) for f in froms)


def _select(entry: dict, path: str, froms: List[FromLine], expected: str) -> List[FromLine]:
    image = entry["image"]
    if "stage" in entry:
        stage = entry["stage"]
        if not isinstance(stage, str) or not stage:
            raise ResolveError("'stage' must be the name of a stage (FROM ... AS <name>)")
        picked = [f for f in froms if f.stage == stage.lower()]
        if not picked:
            names = ", ".join(f.stage for f in froms if f.stage) or "none"
            raise ResolveError(f"{path} has no stage '{stage}' (stages: {names})", path)
    elif "from-index" in entry:
        index = entry["from-index"]
        if isinstance(index, float) and index.is_integer():
            index = int(index)  # 1.0 is an integer to JSON Schema, so the schema accepts it
        if isinstance(index, bool) or not isinstance(index, int) or index < 0:
            raise ResolveError("'from-index' must be a whole number from 0 (the first FROM line)")
        if index >= len(froms):
            raise ResolveError(
                f"'from-index' {index} is out of range: {path} has {len(froms)} FROM line(s), counted from 0", path)
        picked = [froms[index]]
    else:
        picked = [f for f in froms if f.reference and not f.stage_ref
                  and normalize_repository(split_reference(f.reference)[0]) == expected]
        if not picked:
            raise ResolveError(f"no FROM line in {path} uses '{image}'. FROM lines: {_describe(froms)}", path)
        # A line that could not be resolved may use the image on another tag,
        # so the tag of the others would be a guess. Only a line whose
        # repository is written out as another image is certainly not it.
        unknown = [f for f in froms if f.error and _written_repository(f.text) in (None, expected)]
        if unknown:
            raise ResolveError(
                f"{path}: the image or tag of {_describe(unknown)} cannot be read, so it may use '{image}' "
                f"on another tag - fix that line, or set 'stage' or 'from-index' to choose the FROM line "
                f"to monitor", path, unknown[0].line)
        return picked

    chosen = picked[0]
    if chosen.error:
        raise ResolveError(f"{path} line {chosen.line}: {chosen.error}", path, chosen.line)
    if chosen.stage_ref:
        raise ResolveError(
            f"{path} line {chosen.line}: FROM {chosen.reference} builds on an earlier stage, not on an "
            f"image - select the FROM line that names '{image}'", path, chosen.line)
    found = split_reference(chosen.reference)[0]
    if normalize_repository(found) != expected:
        raise ResolveError(
            f"{path} line {chosen.line} uses '{found}', not '{image}'. 'image' is the cross-check for the "
            f"FROM line: correct 'image', or select the FROM line of '{image}'", path, chosen.line)
    return picked


def _tag_of(f: FromLine, path: str) -> str:
    _, tag, digest = split_reference(f.reference)
    if digest is not None and not DIGEST_RE.fullmatch(digest):
        raise ResolveError(f"{path} line {f.line}: '{digest}' is not a valid digest", path, f.line)
    if tag is None:
        if digest is not None:
            raise ResolveError(
                f"{path} line {f.line} pins only a digest ({f.reference}) - there is no tag to monitor. "
                f"Add the tag to the FROM line (image:tag@sha256:...)", path, f.line)
        return "latest"
    if not TAG_RE.fullmatch(tag):
        raise ResolveError(f"{path} line {f.line}: '{tag}' is not a valid tag ({f.text})", path, f.line)
    return tag


def resolve_entry(entry: dict, root: str) -> Resolved:
    """The entry with 'tag' taken from its Dockerfile. Raises ResolveError."""
    path = entry.get("dockerfile")
    if not isinstance(path, str) or not path.strip():
        raise ResolveError("'dockerfile' must be the path of a Dockerfile, relative to the repository root")
    image = entry.get("image")
    if not isinstance(image, str) or not image:
        raise ResolveError("'image' is required with 'dockerfile' - it is the cross-check for the FROM line")
    expected = normalize_repository(image)
    if expected is None:
        raise ResolveError(f"'image' '{image}' is not a valid repository name")
    if "stage" in entry and "from-index" in entry:
        raise ResolveError("set either 'stage' or 'from-index', not both")

    froms = parse_dockerfile(read_dockerfile(root, path))
    if not froms:
        raise ResolveError(f"{path} has no FROM line", path)
    picked = _select(entry, path, froms, expected)

    tags: Dict[str, FromLine] = {}
    for f in picked:
        tags.setdefault(_tag_of(f, path), f)
    if len(tags) > 1:
        found = ", ".join(f"{tag} (line {f.line})" for tag, f in tags.items())
        raise ResolveError(
            f"{path} uses '{image}' with different tags: {found}. Set 'stage' or 'from-index' "
            f"to choose the FROM line to monitor", path)
    tag, chosen = next(iter(tags.items()))

    notices = []
    configured = entry.get("tag")
    if configured is not None and configured != tag:
        # A release that overrides the ARG builds another tag than its default
        # (XPD-SonarQube); then 'tag' was right and 'dockerfile' is not.
        build_arg = (" If the release overrides that ARG with --build-arg, keep 'tag' and remove "
                     "'dockerfile' instead." if "$" in chosen.text else "")
        notices.append((
            f"{entry.get('name', image)}: the configured tag '{configured}' is stale - {path} line "
            f"{chosen.line} builds on '{tag}', which is monitored. Remove 'tag' from the entry: "
            f"with 'dockerfile' the Dockerfile is the source of the tag.{build_arg}", path, chosen.line))
    resolved = dict(entry)
    resolved["tag"] = tag
    return Resolved(resolved, tag, chosen.line, notices)


# --- command line -------------------------------------------------------------

def _escape_data(value: str) -> str:
    return value.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def _escape_property(value: str) -> str:
    return _escape_data(value).replace(":", "%3A").replace(",", "%2C")


def command(kind: str, message: str, file: Optional[str] = None, line: Optional[int] = None) -> str:
    """A workflow command; values are escaped so they cannot start another one."""
    props = []
    if file:
        props.append(f"file={_escape_property(file)}")
        if line:
            props.append(f"line={line}")
    return f"::{kind}{' ' + ','.join(props) if props else ''}::{_escape_data(message)}"


def _plain(value: object) -> str:
    """Config values in a log line, with no line break that could start a workflow command."""
    return re.sub(r"[\x00-\x1f\x7f]", "?", str(value))


def _watched(entry: object, outcome: object) -> Optional[str]:
    """The image:tag an entry is checked on; None when it is not checked."""
    if not isinstance(entry, dict) or isinstance(outcome, ResolveError):
        return None
    tag = outcome.tag if isinstance(outcome, Resolved) else entry.get("tag")
    image = entry.get("image")
    if not isinstance(image, str) or not isinstance(tag, str):
        return None
    return f"{normalize_repository(image) or image}:{tag}"


def shared_variable_errors(outcomes: List[Tuple[object, object]]) -> Dict[int, ResolveError]:
    """Entries with 'dockerfile' whose 'variable' another entry uses for another image:tag.

    Both would be compared with the one digest stored in the variable, so every
    check would find the other one's digest new and release again - easily
    done when an entry is copied for a second Dockerfile. outcomes holds
    (entry, Resolved | ResolveError | None) per entry; the result maps the
    index of each such entry to its error. Entries without 'dockerfile' stay
    as they are: a config without one is checked exactly as before.
    """
    groups: Dict[str, List[int]] = {}
    for index, (entry, outcome) in enumerate(outcomes):
        if _watched(entry, outcome) and isinstance(entry.get("variable"), str):
            groups.setdefault(entry["variable"], []).append(index)
    errors: Dict[int, ResolveError] = {}
    for variable, members in groups.items():
        if len({_watched(*outcomes[i]) for i in members}) < 2:
            continue
        found = ", ".join(f"{outcomes[i][0].get('name', '?')} on {_watched(*outcomes[i])}" for i in members)
        for i in members:
            entry, outcome = outcomes[i]
            if isinstance(outcome, Resolved):
                errors[i] = ResolveError(
                    f"'variable' {variable} is used by entries checked on different images: {found}. Give "
                    f"each image a variable of its own - with one, every check compares one entry's digest "
                    f"with the other's and releases again", entry["dockerfile"], outcome.line)
    return errors


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--output", required=True, help="file the resolved image list is written to")
    parser.add_argument("--root", default=".", help="repository root the 'dockerfile' paths are relative to")
    options = parser.parse_args(argv)
    # The runner reads the log as UTF-8 whatever the locale says; -I (as the
    # action runs this) also ignores PYTHONIOENCODING.
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    try:
        images = json.load(sys.stdin)
    except ValueError as exc:
        print(command("error", f"The image list is not valid JSON: {exc}"))
        return 1
    if not isinstance(images, list):
        print(command("error", "The image list must be a JSON array"))
        return 1

    outcomes: List[Tuple[object, object]] = []
    for entry in images:
        if not isinstance(entry, dict) or "dockerfile" not in entry:
            outcomes.append((entry, None))
            continue
        try:
            outcomes.append((entry, resolve_entry(entry, options.root)))
        except ResolveError as exc:
            outcomes.append((entry, exc))
    for index, error in shared_variable_errors(outcomes).items():
        outcomes[index] = (outcomes[index][0], error)

    resolved: List[object] = []
    unresolved: List[dict] = []
    with_dockerfile = 0
    for entry, result in outcomes:
        if result is None:
            resolved.append(entry)
            continue
        with_dockerfile += 1
        name = entry.get("name", entry.get("image", "?"))
        if isinstance(result, ResolveError):
            print(command("error", f"{name}: {result}", result.file, result.line))
            unresolved.append({"name": name, "image": entry.get("image"),
                               "dockerfile": entry.get("dockerfile"), "error": str(result)})
            continue
        for message, file, line in result.notices:
            print(command("notice", message, file, line))
        print(f"🧭 {_plain(name)}: {_plain(entry['image'])}:{result.tag} "
              f"from {_plain(entry['dockerfile'])} line {result.line}")
        resolved.append(result.entry)

    if unresolved:
        print(f"⏭️  {len(unresolved)} of {with_dockerfile} entries with 'dockerfile' are not checked - the "
              f"errors above say why, and the monitor does not check a guessed tag. "
              f"Fix the entry or its Dockerfile.")
    with open(options.output, "w", encoding="utf-8") as handle:
        json.dump({"images": resolved, "unresolved": unresolved}, handle, separators=(",", ":"), ensure_ascii=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())
