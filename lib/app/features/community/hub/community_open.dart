import 'package:flutter/material.dart';

import '../../../core/models/community.dart';
import 'community_list_controller.dart';
import 'community_post_screen.dart';

/// Ouvre une discussion et reporte ce qui a changé (compteurs, « utile »,
/// suivi, suppression) dans la liste qui l'a ouverte.
Future<void> openCommunityPost(
  BuildContext context, {
  required CommunityPost post,
  CommunityListController? list,
  String source = 'feed',
}) async {
  final outcome = await Navigator.of(context).push<CommunityPostOutcome>(
    MaterialPageRoute<CommunityPostOutcome>(
      builder: (_) => CommunityPostScreen(
        postId: post.id,
        initialPost: post,
        source: source,
      ),
    ),
  );
  if (outcome == null || list == null) return;
  if (outcome.deleted) {
    list.remove(post.id);
  } else if (outcome.post != null) {
    list.replace(outcome.post!);
  }
}
