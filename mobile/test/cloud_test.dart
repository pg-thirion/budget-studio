import 'dart:convert';
import 'dart:io';

import 'package:budget_studio/cloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'inserts a new workspace, guards updates and rejects a stale revision',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'test-key',
      );
      addTearDown(client.dispose);
      final requests = <(String, String?, String?)>[];
      server.listen((request) async {
        final query = request.uri.queryParameters;
        requests.add((request.method, query['user_id'], query['revision']));
        final data = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(
            query['revision'] == 'eq.1'
                ? []
                : [
                    {
                      'revision': data['revision'],
                      'snapshot': data['snapshot'],
                    },
                  ],
          ),
        );
        await request.response.close();
      });
      final cloud = CloudWorkspace(client);
      final snapshot = {
        'months': {
          '2026-11': {'groups': [], 'tx': []},
        },
      };

      expect(await cloud.save('test-user', snapshot, null), 1);
      expect(await cloud.save('test-user', snapshot, 2), 3);
      await expectLater(
        cloud.save('test-user', snapshot, 1),
        throwsA(isA<WorkspaceConflict>()),
      );
      expect(requests, [
        ('POST', null, null),
        ('PATCH', 'eq.test-user', 'eq.2'),
        ('PATCH', 'eq.test-user', 'eq.1'),
      ]);
    },
  );
}
