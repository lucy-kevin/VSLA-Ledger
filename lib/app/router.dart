import 'package:go_router/go_router.dart';
import 'package:vsla_ledger/app/backend.dart';
import 'package:vsla_ledger/core/models/entry_type.dart';
import 'package:vsla_ledger/features/demo/compare_screen.dart';
import 'package:vsla_ledger/features/groups/create_group_screen.dart';
import 'package:vsla_ledger/features/groups/group_screen.dart';
import 'package:vsla_ledger/features/groups/groups_screen.dart';
import 'package:vsla_ledger/features/groups/join_group_screen.dart';
import 'package:vsla_ledger/features/ledger/record_entry_screen.dart';
import 'package:vsla_ledger/features/members/add_member_screen.dart';
import 'package:vsla_ledger/features/members/member_screen.dart';

/// Every screen in the app and its address.
///
///   /                                        your groups
///   /groups/new                              create a group
///   /groups/join                             join a group by its code
///   /groups/:groupId                         one group and its members
///   /groups/:groupId/members/new             add a member
///   /groups/:groupId/members/:memberId       one member's balance and history
///   .../members/:memberId/contribute|lend|repay|social-fund|fine  record
///   .../members/:memberId/compare            talk demo only (DEMO=true)
GoRouter createRouter({required bool withDemoScreens}) => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const GroupsScreen(),
      routes: [
        // Listed before 'groups/:groupId' so "new" and "join" are not read as
        // group ids.
        GoRoute(
          path: 'groups/new',
          builder: (context, state) => const CreateGroupScreen(),
        ),
        GoRoute(
          path: 'groups/join',
          builder: (context, state) => const JoinGroupScreen(),
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
                  ('social-fund', EntryType.socialFund),
                  ('fine', EntryType.fine),
                ])
                  GoRoute(
                    path: path,
                    builder: (context, state) => RecordEntryScreen(
                      groupId: state.pathParameters['groupId']!,
                      memberId: state.pathParameters['memberId']!,
                      type: type,
                    ),
                  ),
                if (withDemoScreens)
                  GoRoute(
                    path: 'compare',
                    builder: (context, state) => CompareScreen(
                      groupId: state.pathParameters['groupId']!,
                      memberId: state.pathParameters['memberId']!,
                      slowNetworkDelay: demoDelay,
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
