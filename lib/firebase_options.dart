import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

import 'config/app_config.dart';
import 'firebase_options_dev.dart';
import 'firebase_options_prod.dart';

/// Environment-aware [FirebaseOptions] router.
/// Routes to `ndrl-notifications-prod` when `APP_ENV=prod`,
/// and defaults to `ndrl-notifications-dev` when `APP_ENV=dev`.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return AppConfig.isProd
        ? ProdFirebaseOptions.currentPlatform
        : DevFirebaseOptions.currentPlatform;
  }
}
