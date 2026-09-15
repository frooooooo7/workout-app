import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/following_user.dart';
import '../../domain/repositories/profile_repository.dart';
import '../bloc/follow_cubit.dart';
import '../widgets/follow_button.dart';
import 'following_list_screen.dart';

/// Wyszukiwarka osób. Wymaga [FollowCubit] w kontekście.
class FindPeopleScreen extends StatefulWidget {
  const FindPeopleScreen({
    super.key,
    required this.repository,
    this.currentUserId,
  });

  final ProfileRepository repository;
  final String? currentUserId;

  @override
  State<FindPeopleScreen> createState() => _FindPeopleScreenState();
}

class _FindPeopleScreenState extends State<FindPeopleScreen> {
  final _controller = TextEditingController();
  late final FollowCubit _followCubit;
  late Future<List<FollowingUser>> _future;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _followCubit = context.read<FollowCubit>();
    _future = _search('');
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<List<FollowingUser>> _search(String query) async {
    final users = await widget.repository.searchUsers(query);
    _followCubit.seedUsers(users);
    return users;
  }

  void _onQueryChanged() {
    final query = _controller.text;
    // Listener odpala się też przy zmianie zaznaczenia/kursora.
    if (query == _lastQuery) return;
    _lastQuery = query;
    setState(() {
      _future = _search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('ZNAJDŹ OSOBY')),
      body: FollowFailureListener(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Szukaj po imieniu lub nazwie użytkownika',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  prefixIcon:
                      const Icon(Icons.search, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<FollowingUser>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    );
                  }
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Nie udało się wyszukać osób.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }
                  final users = snapshot.data ?? const <FollowingUser>[];
                  if (users.isEmpty) {
                    return const Center(
                      child: Text(
                        'Brak wyników.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: users.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      color: AppColors.border,
                      indent: 90,
                    ),
                    itemBuilder: (_, i) => FollowableUserListTile(
                      user: users[i],
                      currentUserId: widget.currentUserId,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
