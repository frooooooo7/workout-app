import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/following_user.dart';
import '../../domain/repositories/profile_repository.dart';
import '../widgets/user_list_tile.dart';

class FollowingListScreen extends StatefulWidget {
  const FollowingListScreen({super.key, required this.repository});

  final ProfileRepository repository;

  @override
  State<FollowingListScreen> createState() => _FollowingListScreenState();
}

class _FollowingListScreenState extends State<FollowingListScreen> {
  late Future<List<FollowingUser>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.getFollowing();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('OBSERWOWANI'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              onPressed: () => context.push('/app/profile/find-people'),
              tooltip: 'Znajdź osoby',
              icon: const Icon(Icons.person_add_outlined),
            ),
          ),
        ],
      ),
      body: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return const Center(
              child: Text(
                'Nie obserwujesz jeszcze nikogo.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.border, indent: 90),
            itemBuilder: (_, i) => UserListTile(user: users[i]),
          );
        },
      ),
    );
  }
}

class FollowersListScreen extends StatefulWidget {
  const FollowersListScreen({super.key, required this.repository});

  final ProfileRepository repository;

  @override
  State<FollowersListScreen> createState() => _FollowersListScreenState();
}

class _FollowersListScreenState extends State<FollowersListScreen> {
  late Future<List<FollowingUser>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.getFollowers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('OBSERWUJĄCY')),
      body: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return const Center(
              child: Text(
                'Brak obserwujących.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.border, indent: 90),
            itemBuilder: (_, i) => UserListTile(user: users[i]),
          );
        },
      ),
    );
  }
}
