import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../shared/widgets/app_snackbar.dart';

import '..//models/resource_config.dart';
import '../providers/resource_provider.dart';

typedef JsonMap = Map<String, dynamic>;

Future<void> postAction(
  BuildContext context,
  WidgetRef ref,
  String endpoint,
  ResourceConfig config,
  String successMessage, {
  JsonMap? data,
}) async {
  try {
    final response = await DioClient().post(
      endpoint,
      data: data ?? const {},
    );

    if (!context.mounted) return;

    if ((response.statusCode == 200 ||
            response.statusCode == 201) &&
        response.data['success'] == true) {
      AppSnackbar.success(context, successMessage);

      ref.invalidate(
        resourceProvider(config),
      );
    } else {
      AppSnackbar.error(
        context,
        response.data['message']?.toString() ??
            'Action failed',
      );
    }
  } catch (error) {
    if (context.mounted) {
      AppSnackbar.error(
        context,
        error.toString(),
      );
    }
  }
}