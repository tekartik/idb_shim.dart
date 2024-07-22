/// Convert an autoAdvance openCursor stream to a list.
Stream<T> streamWithOffsetAndLimit<T>(
    Stream<T> stream, int? offset, int? limit) {
  if ((offset ?? 0) > 0) {
    stream = stream.skip(offset!);
  }
  if ((limit ?? 0) > 0) {
    stream = stream.take(limit!);
  }
  return stream;
}
