part of '../app_controller.dart';

/// Favoris : état local et synchronisation avec le serveur.
mixin _SavedItemsMixin on _AppControllerBase {
  @override
  bool isSaved(SavedItemType type, String itemId) {
    return _savedItems
        .any((item) => item.type == type && item.itemId == itemId);
  }

  void toggleSaved(SavedItemType type, String itemId) {
    if (isSaved(type, itemId)) {
      unawaited(_unsaveItem(type, itemId));
    } else {
      unawaited(_saveItem(type, itemId));
    }
  }

  /// Garantit que l'élément est sauvegardé (sans effet s'il l'est déjà). Rend
  /// la future de la création côté serveur — « Suivre » enchaîne l'alerte
  /// d'ouverture APRÈS elle, pour que les deux écritures ne se croisent pas.
  @override
  Future<void> ensureSaved(SavedItemType type, String itemId) =>
      isSaved(type, itemId) ? Future<void>.value() : _saveItem(type, itemId);

  /// Garantit que l'élément n'est plus sauvegardé. Rend la future de la
  /// suppression côté serveur.
  @override
  Future<void> ensureUnsaved(SavedItemType type, String itemId) =>
      isSaved(type, itemId) ? _unsaveItem(type, itemId) : Future<void>.value();

  Future<void> _unsaveItem(SavedItemType type, String itemId) {
    final index = _savedItems.indexWhere(
      (item) => item.type == type && item.itemId == itemId,
    );
    if (index < 0) return Future<void>.value();
    final existing = _savedItems[index];
    _savedItems.removeAt(index);
    _savedItemTombstones.add(_savedItemKey(type, itemId));
    final remote = _deleteRemoteSavedItem(existing);
    AnalyticsService.instance
        .logUnsaveItem(itemId: itemId, itemType: type.name);
    KpbHaptics.selection();
    _persist();
    update();
    return remote;
  }

  Future<void> _saveItem(SavedItemType type, String itemId) {
    final savedItem = SavedItem(type: type, itemId: itemId);
    _savedItems.add(savedItem);
    // If the user is re-saving an item they just un-saved (the delete may
    // still be in-flight), purge the tombstone — otherwise a sync running
    // before the server confirms the delete would filter this re-save out
    // of mergeSavedItemsUnion and silently drop it.
    _savedItemTombstones.remove(_savedItemKey(type, itemId));
    final remote = _createRemoteSavedItem(savedItem);
    AnalyticsService.instance.logSaveItem(itemId: itemId, itemType: type.name);
    KpbHaptics.confirm();
    _persist();
    update();
    return remote;
  }

  @override
  Future<void> _createRemoteSavedItem(SavedItem item) async {
    if (!AppConfig.enableRemoteSync) return;
    try {
      final response = await _apiClient.createSavedItem(<String, dynamic>{
        'type': item.type.name,
        'itemId': item.itemId,
      });
      final savedId = response['id'] as String?;
      if (savedId != null && savedId.isNotEmpty) {
        _remoteSavedItemIds[_savedItemKey(item.type, item.itemId)] = savedId;
      }
    } catch (e, s) {
      safeRecordError(
        e,
        s,
        reason: 'createRemoteSavedItem',
        domain: CrashlyticsObsDomain.savedItems,
        operation: 'create_remote_saved_item',
      );
    }
  }

  @override
  Future<void> _deleteRemoteSavedItem(SavedItem item) async {
    if (!AppConfig.enableRemoteSync) return;
    try {
      final key = _savedItemKey(item.type, item.itemId);
      final savedId = _remoteSavedItemIds[key];
      if (savedId != null && savedId.isNotEmpty) {
        await _apiClient.deleteSavedItem(savedId);
        _remoteSavedItemIds.remove(key);
        // Server confirmed the delete — tombstone no longer needed.
        _savedItemTombstones.remove(key);
        _persist();
      }
    } catch (e, s) {
      safeRecordError(
        e,
        s,
        reason: 'deleteRemoteSavedItem',
        domain: CrashlyticsObsDomain.savedItems,
        operation: 'delete_remote_saved_item',
      );
    }
  }

  @override
  String _savedItemKey(SavedItemType type, String itemId) =>
      '${type.name}:$itemId';
}
