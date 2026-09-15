import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Szczegóły posta — trasa najwyższego poziomu, działa z każdej zakładki.
/// [focusComment] otwiera ekran z aktywnym polem komentarza.
void openPostDetails(
  BuildContext context,
  String postId, {
  bool focusComment = false,
}) {
  final path = '/app/posts/${Uri.encodeComponent(postId)}';
  context.push(focusComment ? '$path?comment=1' : path);
}

/// Profil autora: własny → zakładka Profil, cudzy → `/app/users/:id`.
void openAuthorProfile(
  BuildContext context,
  String userId, {
  required bool isOwn,
}) {
  if (isOwn) {
    context.go('/app/profile');
    return;
  }
  context.push('/app/users/${Uri.encodeComponent(userId)}');
}
