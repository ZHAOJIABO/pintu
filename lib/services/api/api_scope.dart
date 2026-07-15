import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'generation_completion_service.dart';
import 'api_models.dart';
import 'api_repositories.dart';
import 'api_session_store.dart';

class BackendServices {
  Future<PagedResult<TemplateItem>>? _homeTemplatesRequest;

  final ApiSessionStore store;
  final ApiClient client;
  final AuthSessionController auth;
  final TemplateRepository templates;
  final MediaRepository media;
  final AIGenerationRepository aiGenerations;
  final GenerationRepository generations;
  final GenerationCompletionService generationCompletion;
  final WorkRepository works;
  final CreditRepository credits;
  final SystemRepository system;

  BackendServices._({
    required this.store,
    required this.client,
    required this.auth,
    required this.templates,
    required this.media,
    required this.aiGenerations,
    required this.generations,
    required this.generationCompletion,
    required this.works,
    required this.credits,
    required this.system,
  });

  factory BackendServices({
    String baseUrl = ApiClient.defaultBaseUrl,
    http.Client? httpClient,
    ApiSessionStore? store,
  }) {
    final sessionStore = store ?? const ApiSessionStore();
    late final AuthSessionController auth;
    late final ApiClient client;

    client = ApiClient(
      baseUrl: baseUrl,
      httpClient: httpClient,
      tokenProvider: sessionStore.readAccessToken,
      deviceIdProvider: sessionStore.readOrCreateDeviceId,
      onUnauthorized: () => auth.refreshOrGuestLogin(),
    );
    auth = AuthSessionController(
      store: sessionStore,
      repository: AuthRepository(client),
    );
    final media = MediaRepository(apiClient: client, auth: auth);
    final generations = GenerationRepository(apiClient: client, auth: auth);

    return BackendServices._(
      store: sessionStore,
      client: client,
      auth: auth,
      templates: TemplateRepository(apiClient: client, auth: auth),
      media: media,
      aiGenerations: AIGenerationRepository(apiClient: client, auth: auth),
      generations: generations,
      generationCompletion: GenerationCompletionService(
        media: media,
        generations: generations,
        store: sessionStore,
      ),
      works: WorkRepository(apiClient: client, auth: auth),
      credits: CreditRepository(apiClient: client, auth: auth),
      system: SystemRepository(client),
    );
  }

  Future<void> warmUp() async {
    await auth.ensureSignedIn();

    // The detail endpoint needs an id, so start the home list first and warm
    // the first available template once the shared startup requests complete.
    final homeTemplates = loadHomeTemplates();
    await Future.wait<void>([
      system.getConfig().then((_) {}),
      system.listBoardSpecs().then((_) {}),
      system.listBeadColors().then((_) {}),
      templates.listCategories().then((_) {}),
    ]);

    final firstTemplate = (await homeTemplates).items.firstOrNull;
    if (firstTemplate != null && firstTemplate.templateId.isNotEmpty) {
      await templates.getTemplate(firstTemplate.templateId);
    }
  }

  Future<PagedResult<TemplateItem>> loadHomeTemplates() async {
    final existing = _homeTemplatesRequest;
    if (existing != null) return existing;

    final request = templates.listTemplates(scene: 'home');
    _homeTemplatesRequest = request;
    try {
      return await request;
    } catch (_) {
      if (identical(_homeTemplatesRequest, request)) {
        _homeTemplatesRequest = null;
      }
      rethrow;
    }
  }
}

class BackendScope extends InheritedWidget {
  final BackendServices services;

  const BackendScope({super.key, required this.services, required super.child});

  static BackendServices? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<BackendScope>()?.services;
  }

  static BackendServices of(BuildContext context) {
    final services = maybeOf(context);
    assert(services != null, 'No BackendScope found in context');
    return services!;
  }

  @override
  bool updateShouldNotify(covariant BackendScope oldWidget) {
    return oldWidget.services != services;
  }
}

class BackendWarmUp extends StatefulWidget {
  final BackendServices services;
  final bool enabled;
  final Widget child;

  const BackendWarmUp({
    super.key,
    required this.services,
    required this.enabled,
    required this.child,
  });

  @override
  State<BackendWarmUp> createState() => _BackendWarmUpState();
}

class _BackendWarmUpState extends State<BackendWarmUp> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || !widget.enabled) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.services.warmUp().catchError((_) {}));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
