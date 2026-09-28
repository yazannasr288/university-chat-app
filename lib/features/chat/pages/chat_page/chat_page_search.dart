part of '../chat_page.dart';

extension on _ChatPageState {
  void _openChatSearch() {
    _safeSetState(() => _isSearching = true);
  }

  void _closeChatSearch() {
    _chatSearchController.clear();
    _safeSetState(() => _isSearching = false);
  }

  PreferredSizeWidget _buildSearchHeader() {
    return AppBar(
      key: const ValueKey('chat_search_header'),
      toolbarHeight: 64,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: AppGradients.appBar),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: _closeChatSearch,
      ),
      titleSpacing: 0,
      title: TextField(
        controller: _chatSearchController,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onChanged: (_) => _safeSetState(() {}),
        style: context.textTheme.titleMedium?.copyWith(
          color: context.appTextPrimary,
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          hintText: 'chat.search_in_conversation'.tr(),
          hintStyle: context.textTheme.titleMedium?.copyWith(
            color: context.appTextSecondary,
            fontWeight: FontWeight.w700,
          ),
          border: InputBorder.none,
        ),
      ),
      actions: [
        if (_chatSearchController.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () {
              _chatSearchController.clear();
              _safeSetState(() {});
            },
          ),
      ],
    );
  }
}
