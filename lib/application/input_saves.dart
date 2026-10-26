/// Mounted editors participate in explicit completion/navigation barriers.
/// Composition remains local until the input method commits it.
class InputSaves {
  final _editors = <Future<void> Function()>{};
  void Function() register(Future<void> Function() flush) {
    _editors.add(flush);
    return () => _editors.remove(flush);
  }

  Future<void> flush() async {
    for (final editor in _editors.toList()) {
      await editor();
    }
  }
}
