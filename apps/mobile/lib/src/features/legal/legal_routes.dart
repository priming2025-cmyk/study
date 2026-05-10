import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'legal_copy.dart';
import 'legal_document_screen.dart';

List<GoRoute> buildLegalRoutes(GlobalKey<NavigatorState> rootKey) => [
      GoRoute(
        parentNavigatorKey: rootKey,
        path: '/legal/terms',
        builder: (context, state) => const LegalDocumentScreen(
          title: LegalCopy.termsTitle,
          body: LegalCopy.termsBody,
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootKey,
        path: '/legal/privacy',
        builder: (context, state) => const LegalDocumentScreen(
          title: LegalCopy.privacyTitle,
          body: LegalCopy.privacyBody,
        ),
      ),
    ];
