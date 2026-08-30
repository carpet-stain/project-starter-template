// EOL normalization for the base/theirs/ours diff (#157 thread 15). The
// prior bash `tr -d '\r'` deleted every \r byte in the file, not just
// line-ending ones — a local edit with a meaningful embedded \r (not part of
// a CRLF pair) got misclassified as "unchanged" and silently overwritten.
// Only a \r immediately followed by \n is a line ending here; any other \r
// is content and survives untouched.

/**
 * @param {string} text
 * @returns {string} CRLF collapsed to LF, any other \r preserved, trailing
 *   newlines collapsed to exactly one (same trailing-newline behavior as the
 *   prior `printf '%s\n' "$(...)"` idiom, including on empty input).
 */
export function normalizeEols(text) {
  const lfOnly = text.replace(/\r\n/g, "\n");
  return lfOnly.replace(/\n+$/, "") + "\n";
}
