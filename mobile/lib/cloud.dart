import 'package:supabase_flutter/supabase_flutter.dart';

import 'workspace.dart';

class WorkspaceConflict implements Exception {
  const WorkspaceConflict();
}

class CloudWorkspace {
  CloudWorkspace(this.client);

  final SupabaseClient client;

  Future<({Json? snapshot, int? revision})> load(String userId) async {
    final row = await client
        .from('budget_workspaces')
        .select('snapshot,revision')
        .eq('user_id', userId)
        .maybeSingle();
    return (
      snapshot: row?['snapshot'] as Json?,
      revision: row?['revision'] as int?,
    );
  }

  Future<int> save(String userId, Json snapshot, int? revision) async {
    final next = (revision ?? 0) + 1;
    final values = {'snapshot': snapshot, 'revision': next};
    try {
      final rows = revision == null
          ? await client
                .from('budget_workspaces')
                .insert({'user_id': userId, ...values})
                .select('snapshot,revision')
          : await client
                .from('budget_workspaces')
                .update(values)
                .eq('user_id', userId)
                .eq('revision', revision)
                .select('snapshot,revision');
      if (rows.length != 1 || rows.first['revision'] != next) {
        throw const WorkspaceConflict();
      }
      if (!_sameJson(rows.single['snapshot'], snapshot)) {
        throw const FormatException('The cloud save could not be verified');
      }
      return next;
    } on PostgrestException catch (error) {
      if (error.code == '23505') throw const WorkspaceConflict();
      rethrow;
    }
  }
}

bool _sameJson(Object? left, Object? right) {
  if (left is Map && right is Map) {
    return left.length == right.length &&
        left.keys.every(
          (key) => right.containsKey(key) && _sameJson(left[key], right[key]),
        );
  }
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (!_sameJson(left[i], right[i])) return false;
    }
    return true;
  }
  return left == right;
}
