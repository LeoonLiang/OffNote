Set<String> toggleVisibleSelection({
  required Set<String> selectedIds,
  required Iterable<String> visibleIds,
}) {
  final visible = visibleIds.toSet();
  if (visible.isEmpty) {
    return Set<String>.from(selectedIds);
  }
  final next = Set<String>.from(selectedIds);
  final allVisibleSelected = visible.every(next.contains);
  if (allVisibleSelected) {
    next.removeAll(visible);
  } else {
    next.addAll(visible);
  }
  return next;
}
