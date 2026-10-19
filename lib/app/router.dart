import 'package:go_router/go_router.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';
import 'package:vsla_ledger/features/groups/create_group_screen.dart';
import 'package:vsla_ledger/features/groups/group_screen.dart';
import 'package:vsla_ledger/features/groups/groups_screen.dart';
import 'package:vsla_ledger/features/ledger/record_entry_screen.dart';
import 'package:vsla_ledger/features/members/add_member_screen.dart';
import 'package:vsla_ledger/features/members/member_screen.dart';

/// Every screen in the app and its address.
///
///   /                                        your groups
///   /groups/new                              create a group
///   /groups/:groupId                         one group and its members
///   /groups/:groupId/members/new             add a member
///   /groups/:groupId/members/:memberId       one member's balance and history
///   .../members/:memberId/contribute|lend|repay   record an entry
GoRouter createRouter() => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const GroupsScreen(),
      routes: [
        // Listed before 'groups/:groupId' so "new" is not read as an id.
        GoRoute(
          path: 'groups/new',
          builder: (context, state) => const CreateGroupScreen(),
        ),
        GoRoute(
          path: 'groups/:groupId',
          builder: (context, state) =>
              GroupScreen(groupId: state.pathParameters['groupId']!),
          routes: [
            GoRoute(
              path: 'members/new',
              builder: (context, state) =>
                  AddMemberScreen(groupId: state.pathParameters['groupId']!),
            ),
            GoRoute(
              path: 'members/:memberId',
              builder: (context, state) => MemberScreen(
                groupId: state.pathParameters['groupId']!,
                memberId: state.pathParameters['memberId']!,
              ),
              routes: [
                for (final (path, type) in [
                  ('contribute', EntryType.contribution),
                  ('lend', EntryType.loan),
                  ('repay', EntryType.repayment),
                ])
                  GoRoute(
                    path: path,
                    builder: (context, state) => RecordEntryScreen(
                      groupId: state.pathParameters['groupId']!,
                      memberId: state.pathParameters['memberId']!,
                      type: type,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
