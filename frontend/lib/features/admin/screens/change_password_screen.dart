import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/router/app_router.dart';

import '../../../shared/widgets/app_snackbar.dart';

import '../widgets/page_hero.dart';
import '../widgets/section_card.dart';

class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();

    final client = DioClient();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHero(
            title: 'Change Password',
            subtitle: 'Update the password for your current session.',
            icon: Icons.lock_reset_rounded,
          ),

          const SizedBox(height: 16),

          SectionCard(
            title: 'Security',
            icon: Icons.password_rounded,
            child: SizedBox(
              width: 520,
              child: Column(
                children: [
                  TextField(
                    controller: current,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current password',
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: next,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New password',
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: confirm,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm new password',
                    ),
                  ),

                  const SizedBox(height: 16),

                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Update Password'),
                      onPressed: () async {
                        if (next.text != confirm.text) {
                          AppSnackbar.error(
                            context,
                            'New password and confirmation do not match',
                          );
                          return;
                        }

                        final response = await client.post(
                          ApiEndpoints.changePassword,
                          data: {
                            'currentPassword': current.text,
                            'newPassword': next.text,
                          },
                        );

                        if (context.mounted &&
                            response.data['success'] == true) {
                          AppSnackbar.success(
                            context,
                            'Password changed',
                          );

                          context.goNamed(
                            RouteNames.dashboard,
                          );
                        } else if (context.mounted) {
                          AppSnackbar.error(
                            context,
                            response.data['message']?.toString() ??
                                'Unable to change password',
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}