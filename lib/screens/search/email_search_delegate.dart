import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_application/models/email_data.dart';
import 'package:email_application/models/label_data.dart';
import 'package:email_application/models/email_folder.dart';
import 'package:email_application/services/firestore_service.dart';
import 'package:email_application/widgets/email_list_view.dart';
import 'package:email_application/widgets/email_list_item.dart';
import 'package:email_application/screens/emails/view_email_screen.dart';
import 'package:email_application/screens/compose/compose_email_screen.dart';
import 'package:email_application/config/app_colors.dart';

class SearchResultPayload {
  final List<EmailData> emails;
  final List<LabelData> allUserLabels;
  final bool hasMoreSuggestions;

  SearchResultPayload({
    required this.emails,
    required this.allUserLabels,
    this.hasMoreSuggestions = false,
  });
}

class EmailSearchDelegate extends SearchDelegate<String?> {
  final String userId;
  List<LabelData> _allUserLabelsCache = [];
  bool _labelsFetchedForSession = false;

  String _lastSuggestionQuery = '';
  SearchResultPayload? _lastSuggestionsPayload;

  String _lastFullResultQuery = '';
  SearchResultPayload? _lastFullResultsPayload;

  static const int _suggestionLimit = 5;
  bool _isActive = true;

  BuildContext? _delegateBuildContext;

  EmailSearchDelegate({required this.userId});

  @override
  ThemeData appBarTheme(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return theme.copyWith(
      primaryColor: AppColors.appBarBackground,
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: AppColors.appBarBackground,
        elevation: 1.0,
        iconTheme: IconThemeData(color: AppColors.primary),
        titleTextStyle: TextStyle(
          color: AppColors.appBarForeground,
          fontSize: 18,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: AppColors.secondaryText.withOpacity(0.7)),
        border: InputBorder.none,
      ),
      textTheme: theme.textTheme.copyWith(
        titleLarge: TextStyle(
          color: AppColors.appBarForeground,
          fontSize: 18,
          fontWeight: FontWeight.normal,
        ),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    _delegateBuildContext = context;
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          tooltip: 'Clear',
          onPressed: () {
            query = '';
            _lastSuggestionQuery = '';
            _lastSuggestionsPayload = null;
            _lastFullResultQuery = '';
            _lastFullResultsPayload = null;
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    _delegateBuildContext = context;
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Back',
      onPressed: () {
        _isActive = false;
        close(context, null);
      },
    );
  }

  void _tryRefreshSuggestions() {
    if (_isActive &&
        _delegateBuildContext != null &&
        (_delegateBuildContext?.mounted ?? false) &&
        (ModalRoute.of(_delegateBuildContext!)?.isActive ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isActive && (_delegateBuildContext?.mounted ?? false)) {
          showSuggestions(_delegateBuildContext!);
        }
      });
    } else {
      print("SearchDelegate: Suppressed _tryRefreshSuggestions call.");
    }
  }

  void _tryRefreshResults() {
    if (_isActive &&
        _delegateBuildContext != null &&
        (_delegateBuildContext?.mounted ?? false) &&
        (ModalRoute.of(_delegateBuildContext!)?.isActive ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isActive && (_delegateBuildContext?.mounted ?? false)) {
          showResults(_delegateBuildContext!);
        }
      });
    } else {
      print("SearchDelegate: Suppressed _tryRefreshResults call.");
    }
  }

  @override
  Widget buildResults(BuildContext context) {
    _delegateBuildContext = context;
    if (!_isActive) return const SizedBox.shrink();

    if (query != _lastFullResultQuery) {
      _lastFullResultQuery = query;
      _lastFullResultsPayload = null;
    }
    return _buildSearchResultsView(context, isFullResults: true);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    _delegateBuildContext = context;
    if (!_isActive) return const SizedBox.shrink();

    if (query != _lastSuggestionQuery) {
      _lastSuggestionQuery = query;
      _lastSuggestionsPayload = null;
    }
    return _buildSearchResultsView(context, isFullResults: false);
  }

  Widget _buildSearchResultsView(
    BuildContext context, {
    required bool isFullResults,
  }) {
    _delegateBuildContext = context;
    if (!_isActive) return const SizedBox.shrink();

    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final String currentQuery = query.trim();

    if (currentQuery.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              "Search emails by subject, body, or people.",
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final SearchResultPayload? cachedPayload =
        isFullResults ? _lastFullResultsPayload : _lastSuggestionsPayload;
    final String lastProcessedQuery =
        isFullResults ? _lastFullResultQuery : _lastSuggestionQuery;

    final Future<SearchResultPayload> fetchFuture =
        (cachedPayload != null &&
                currentQuery == lastProcessedQuery &&
                currentQuery.isNotEmpty)
            ? Future.value(cachedPayload)
            : _performSearchAndFetchData(
              firestoreService,
              userId,
              currentQuery,
              limit: isFullResults ? null : _suggestionLimit,
              isForSuggestions: !isFullResults,
            );

    return FutureBuilder<SearchResultPayload>(
      future: fetchFuture,
      builder: (context, snapshot) {
        _delegateBuildContext = context;
        if (!_isActive) return const SizedBox.shrink();

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return EmailListErrorView(
            error: "Search failed: ${snapshot.error}",
            onRetry: () async {
              if (isFullResults) {
                _lastFullResultsPayload = null;
                _tryRefreshResults();
              } else {
                _lastSuggestionsPayload = null;
                _tryRefreshSuggestions();
              }
            },
          );
        }

        final SearchResultPayload payload =
            snapshot.data ??
            SearchResultPayload(
              emails: [],
              allUserLabels: _allUserLabelsCache,
              hasMoreSuggestions: false,
            );
        if (isFullResults) {
          _lastFullResultsPayload = payload;
          _lastFullResultQuery = currentQuery;
        } else {
          _lastSuggestionsPayload = payload;
          _lastSuggestionQuery = currentQuery;
        }
        _allUserLabelsCache = payload.allUserLabels;
        if (payload.emails.isEmpty && currentQuery.isNotEmpty) {
          return Center(child: Text("No emails found for \"$currentQuery\"."));
        }

        bool shouldShowSeeAllButton =
            !isFullResults && payload.hasMoreSuggestions;

        return ListView.builder(
          itemCount: payload.emails.length + (shouldShowSeeAllButton ? 1 : 0),
          itemBuilder: (itemBuilderContext, index) {
            _delegateBuildContext = itemBuilderContext;
            if (shouldShowSeeAllButton && index == payload.emails.length) {
              return ListTile(
                leading: const Icon(Icons.manage_search_outlined),
                title: Text(
                  "See all results for \"$currentQuery\"",
                  style: TextStyle(color: AppColors.primary),
                ),
                onTap: () => _tryRefreshResults(),
              );
            }

            final email = payload.emails[index];
            return EmailListItem(
              email: email,
              currentScreenFolder: email.folder,
              allUserLabels: payload.allUserLabels,
              onTap: () async {
                Widget screenToPush;
                if (email.folder == EmailFolder.drafts) {
                  screenToPush = ComposeEmailScreen(draftToEdit: email);
                } else {
                  screenToPush = ViewEmailScreen(emailData: email);
                }

                final value = await Navigator.push(
                  itemBuilderContext,
                  MaterialPageRoute(builder: (navContext) => screenToPush),
                );

                if (_isActive && value == true) {
                  if (isFullResults) {
                    _lastFullResultsPayload = null;
                    _tryRefreshResults();
                  } else {
                    _lastSuggestionsPayload = null;
                    _tryRefreshSuggestions();
                  }
                }
              },
              onStarStatusChanged: () {
                if (isFullResults) {
                  _lastFullResultsPayload = null;
                  _tryRefreshResults();
                } else {
                  _lastSuggestionsPayload = null;
                  _tryRefreshSuggestions();
                }
              },
              onDeleteOrMove: () {
                if (isFullResults) {
                  _lastFullResultsPayload = null;
                  _tryRefreshResults();
                } else {
                  _lastSuggestionsPayload = null;
                  _tryRefreshSuggestions();
                }
              },
              onReadStatusChanged: () {
                if (isFullResults) {
                  _lastFullResultsPayload = null;
                  _tryRefreshResults();
                } else {
                  _lastSuggestionsPayload = null;
                  _tryRefreshSuggestions();
                }
              },
            );
          },
        );
      },
    );
  }

  Future<SearchResultPayload> _performSearchAndFetchData(
    FirestoreService fs,
    String currentUserId,
    String searchTerm, {
    int? limit,
    bool isForSuggestions = false,
  }) async {
    if (!_isActive)
      return SearchResultPayload(
        emails: [],
        allUserLabels: _allUserLabelsCache,
        hasMoreSuggestions: false,
      );

    if (!_labelsFetchedForSession || _allUserLabelsCache.isEmpty) {
      _allUserLabelsCache = await fs.getLabelsForUser(currentUserId);
      if (!_isActive)
        return SearchResultPayload(
          emails: [],
          allUserLabels: _allUserLabelsCache,
          hasMoreSuggestions: false,
        );
      _labelsFetchedForSession = true;
    }

    List<EmailData> emails;
    bool actualHasMore = false;

    if (isForSuggestions && limit != null && limit > 0) {
      final List<Map<String, dynamic>> emailMaps = await fs.searchEmailsBasic(
        currentUserId,
        searchTerm,
        limitResults: limit + 1,
      );
      if (!_isActive)
        return SearchResultPayload(
          emails: [],
          allUserLabels: _allUserLabelsCache,
          hasMoreSuggestions: false,
        );
      if (emailMaps.length > limit) {
        actualHasMore = true;
        emails =
            emailMaps
                .take(limit)
                .map(
                  (map) => EmailData.fromMap(map, map['id'] as String? ?? ''),
                )
                .toList();
      } else {
        emails =
            emailMaps
                .map(
                  (map) => EmailData.fromMap(map, map['id'] as String? ?? ''),
                )
                .toList();
      }
    } else {
      final List<Map<String, dynamic>> emailMaps = await fs.searchEmailsBasic(
        currentUserId,
        searchTerm,
        limitResults: limit,
      );
      if (!_isActive)
        return SearchResultPayload(
          emails: [],
          allUserLabels: _allUserLabelsCache,
          hasMoreSuggestions: false,
        );
      emails =
          emailMaps
              .map((map) => EmailData.fromMap(map, map['id'] as String? ?? ''))
              .toList();
    }

    print(
      "Search (limit: $limit) returned ${emails.length} emails for query: $searchTerm. HasMore: $actualHasMore",
    );
    return SearchResultPayload(
      emails: emails,
      allUserLabels: _allUserLabelsCache,
      hasMoreSuggestions: actualHasMore,
    );
  }
}
