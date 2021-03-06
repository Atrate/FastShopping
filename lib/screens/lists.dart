import 'package:animations/animations.dart';
import 'package:fast_shopping/l10n/l10n.dart';
import 'package:fast_shopping/l10n/timeago.dart';
import 'package:fast_shopping/models/models.dart';
import 'package:fast_shopping/screens/rename_list_dialog.dart';
import 'package:fast_shopping/screens/screens.dart';
import 'package:fast_shopping/store/store.dart';
import 'package:fast_shopping/utils/extensions.dart';
import 'package:flutter/material.dart' hide SimpleDialog;
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:md2_tab_indicator/md2_tab_indicator.dart';

class ListsScreen extends StatefulWidget {
  @override
  _ListsScreenState createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen>
    with SingleTickerProviderStateMixin {
  TabController _tabController;

  bool _fabShown = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..animation.addListener(() {
        if (_tabController.animation.value < 0.5 && !_fabShown) {
          setState(() => _fabShown = true);
        } else if (_tabController.animation.value >= 0.5 && _fabShown) {
          setState(() => _fabShown = false);
        }
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(S.of(context).shopping_lists_title),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          indicatorSize: TabBarIndicatorSize.label,
          indicator: const MD2Indicator(
            indicatorColor: Colors.black,
            indicatorHeight: 3,
            indicatorSize: MD2IndicatorSize.normal,
          ),
          tabs: [
            Tab(
              icon: const Icon(Icons.local_grocery_store),
              text: S.of(context).shopping_lists_tab_current,
            ),
            Tab(
              icon: const Icon(Icons.archive),
              text: S.of(context).shopping_lists_tab_archived,
            ),
          ],
        ),
      ),
      floatingActionButton: _fabShown ? const _FloatingActionButton() : null,
      body: _Body(tabController: _tabController),
    );
  }
}

class _FloatingActionButton extends StatelessWidget {
  const _FloatingActionButton();

  @override
  Widget build(BuildContext context) {
    final store = context.store;

    return FloatingActionButton.extended(
      icon: const Icon(Icons.add),
      label: Text(S.of(context).shopping_lists_add_new),
      onPressed: () async {
        final name = await showModal(
          context: context,
          configuration: FadeScaleTransitionConfiguration(),
          builder: (context) => AddListDialog(),
        );

        if (name != null) {
          store.dispatch(addShoppingList(name as String));

          Navigator.of(context).pop();
        }
      },
    );
  }
}

class _Body extends StatelessWidget {
  final TabController tabController;

  const _Body({Key key, @required this.tabController}) : super(key: key);

  void _showSnackbar(BuildContext context, String content) {
    Scaffold.of(context).hideCurrentSnackBar();
    Scaffold.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(content),
      ),
    );
  }

  void _onRenameList(BuildContext context, ShoppingList list) async {
    final newName = await showModal(
      context: context,
      configuration: FadeScaleTransitionConfiguration(),
      builder: (context) => RenameListDialog(
        initialName: list.name,
      ),
    );

    if (newName != null) {
      context.store.dispatch(RenameShoppingList(list, newName as String));
    }
  }

  void _onArchiveList(BuildContext context, ShoppingList list) {
    _showSnackbar(
        context, S.of(context).shopping_list_archived_snackbar_message);

    context.store.dispatch(ArchiveShoppingList(list));
  }

  void _onUnarchiveList(BuildContext context, ShoppingList list) {
    _showSnackbar(
        context, S.of(context).shopping_list_unarchived_snackbar_message);

    context.store.dispatch(UnarchiveShoppingList(list));
  }

  void _onDeleteTap(BuildContext context, ShoppingList list) async {
    final result = await showModal(
      context: context,
      configuration: FadeScaleTransitionConfiguration(),
      builder: (context) => DeleteListDialog(
        listName: list.name,
      ),
    );

    if (result != null) {
      context.store.dispatch(RemoveShoppingList(list));
    }
  }

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      controller: tabController,
      children: [
        _buildCurrentTab(context),
        _buildArchivedTab(context),
      ],
    );
  }

  Widget _buildCurrentTab(BuildContext context) {
    return StoreConnector<FastShoppingState, List<ShoppingList>>(
      converter: (store) => ListsSelectors.allCurrent(store),
      builder: (builder, lists) => _ShoppingListTab(
        lists: lists,
        onTap: (list) {
          context.store.dispatch(SetCurrentShoppingList(list));
          // Go back to main screen.
          Navigator.pop(context);
        },
        thirdLineBuilder: (list) => S
            .of(context)
            .shopping_lists_item_created_at(list.createdAt.timeAgo(context)),
        emptyPlaceholder: const _CurrentTabPlaceholder(),
        trailingBuilder: (list) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _onRenameList(context, list),
            ),
            IconButton(
              icon: const Icon(Icons.archive),
              onPressed: () => _onArchiveList(context, list),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArchivedTab(BuildContext context) {
    return StoreConnector<FastShoppingState, List<ShoppingList>>(
      converter: (store) => ListsSelectors.allArchived(store),
      builder: (context, lists) => _ShoppingListTab(
        lists: lists,
        thirdLineBuilder: (list) => S
            .of(context)
            .shopping_lists_item_archived_at(list.archivedAt.timeAgo(context)),
        emptyPlaceholder: Center(
          child: Text(S.of(context).no_archived_lists_message),
        ),
        trailingBuilder: (list) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.unarchive),
              onPressed: () => _onUnarchiveList(context, list),
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever),
              onPressed: () => _onDeleteTap(context, list),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShoppingListTab extends StatelessWidget {
  final List<ShoppingList> lists;
  final void Function(ShoppingList) onTap;
  final String Function(ShoppingList) thirdLineBuilder;
  final Widget Function(ShoppingList) trailingBuilder;
  final Widget emptyPlaceholder;

  const _ShoppingListTab({
    Key key,
    @required this.lists,
    this.onTap,
    this.thirdLineBuilder,
    this.trailingBuilder,
    this.emptyPlaceholder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return lists.isEmpty
        ? SizedBox(child: emptyPlaceholder)
        : ListView.builder(
            padding: const EdgeInsets.only(bottom: 72),
            itemCount: lists.length,
            itemBuilder: (context, i) {
              final list = lists[i];

              return _buildListRow(context, list);
            },
          );
  }

  Widget _buildListRow(BuildContext context, ShoppingList list) {
    final itemsCount = ItemsSelectors.itemsCount(context.store, list.id);
    final current = ListsSelectors.currentList(context.store)?.id == list.id;

    String subtitle = S.of(context).shopping_lists_item_elements(itemsCount);
    if (thirdLineBuilder != null) {
      subtitle += '\n' + thirdLineBuilder(list);
    }

    return Container(
      color: current ? Theme.of(context).primaryColor.withOpacity(.2) : null,
      child: ListTile(
        leading: const Icon(Icons.list),
        title: Text(
          list.name.isNotEmpty
              ? list.name
              : S.of(context).shopping_list_no_name,
          style: TextStyle(
            fontWeight: current ? FontWeight.bold : null,
            fontStyle: list.name.isEmpty ? FontStyle.italic : null,
          ),
        ),
        isThreeLine: thirdLineBuilder != null,
        subtitle: Text(
          subtitle,
        ),
        onTap: onTap == null ? null : () => onTap(list),
        trailing: trailingBuilder?.call(list),
      ),
    );
  }
}

class _CurrentTabPlaceholder extends StatelessWidget {
  const _CurrentTabPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SvgPicture.asset('assets/shopping_bags_woman.svg', width: 250),
        const SizedBox(height: 32),
        Text(S.of(context).no_current_lists_message),
      ],
    );
  }
}
