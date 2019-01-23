import 'package:Openbook/models/emoji.dart';
import 'package:Openbook/models/post.dart';
import 'package:Openbook/models/post_reaction.dart';
import 'package:Openbook/provider.dart';
import 'package:Openbook/services/navigation_service.dart';
import 'package:Openbook/services/toast.dart';
import 'package:Openbook/services/user.dart';
import 'package:Openbook/widgets/progress_indicator.dart';
import 'package:Openbook/widgets/tiles/post_reaction_tile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:loadmore/loadmore.dart';

class OBPostReactionList extends StatefulWidget {
  // The emoji to show reactions of
  final Emoji emoji;

  // The post to show reactions of
  final Post post;

  const OBPostReactionList({Key key, this.emoji, this.post}) : super(key: key);

  @override
  OBPostReactionListState createState() {
    return OBPostReactionListState();
  }
}

class OBPostReactionListState extends State<OBPostReactionList> {
  UserService _userService;
  ToastService _toastService;
  NavigationService _navigationService;

  List<PostReaction> _postReactions;

  bool _needsBootstrap;
  bool _refreshInProgress;
  bool _loadMoreFinished;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    _needsBootstrap = true;
    _refreshInProgress = false;
    _loadMoreFinished = false;
    _postReactions = [];
  }

  @override
  Widget build(BuildContext context) {
    if (_needsBootstrap) {
      var openbookProvider = OpenbookProvider.of(context);
      _userService = openbookProvider.userService;
      _toastService = openbookProvider.toastService;
      _navigationService = openbookProvider.navigationService;
      _bootstrap();
      _needsBootstrap = false;
    }

    return RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _onRefresh,
        child: LoadMore(
            whenEmptyLoad: false,
            isFinish: _loadMoreFinished,
            delegate: OBPostReactionListLoadMoreDelegate(),
            child: ListView.builder(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(0),
                itemCount: _postReactions.length,
                itemBuilder: (context, index) {
                  var postReaction = _postReactions[index];
                  return OBPostReactionTile(
                    postReaction: postReaction,
                    key: Key(
                      postReaction.id.toString(),
                    ),
                    onPostReactionTilePressed: _onPostReactionTilePressed,
                  );
                }),
            onLoadMore: _loadMorePostReactions));
  }

  Future<void> _onRefresh() {
    return _refreshPostReactions();
  }

  Future<void> _refreshPostReactions() async {
    _setRefreshInProgress(true);
    var reactionsList = await _userService.getReactionsForPost(widget.post,
        emoji: widget.emoji);

    _setPostReactions(reactionsList.reactions);
    _setRefreshInProgress(false);
  }

  Future<bool> _loadMorePostReactions() async {
    var lastReaction = _postReactions.last;
    var lastReactionId = lastReaction.id;
    try {
      var moreReactions = (await _userService.getReactionsForPost(widget.post,
              maxId: lastReactionId, emoji: widget.emoji))
          .reactions;

      if (moreReactions.length == 0) {
        _setLoadMoreFinished(true);
      } else {
        _addPostReactions(moreReactions);
      }
      return true;
    } on HttpieConnectionRefusedError {
      _toastService.error(message: 'No internet connection', context: context);
    } catch (error) {
      _toastService.error(message: 'Unknown error', context: context);
      rethrow;
    }

    return false;
  }

  void _onPostReactionTilePressed(PostReaction postReaction) {
    _navigationService.navigateToUserProfile(
        user: postReaction.reactor, context: context);
  }

  void _setPostReactions(List<PostReaction> reactions) {
    setState(() {
      _postReactions = reactions;
    });
  }

  void _addPostReactions(List<PostReaction> reactions) {
    setState(() {
      _postReactions.addAll(reactions);
    });
  }

  void _setLoadMoreFinished(bool loadMoreFinished) {
    setState(() {
      _loadMoreFinished = loadMoreFinished;
    });
  }

  void _setRefreshInProgress(bool refreshInProgress) {
    setState(() {
      _refreshInProgress = refreshInProgress;
    });
  }

  void _bootstrap() {
    _refreshPostReactions();
  }
}

class OBPostReactionListLoadMoreDelegate extends LoadMoreDelegate {
  const OBPostReactionListLoadMoreDelegate();

  @override
  Widget buildChild(LoadMoreStatus status,
      {LoadMoreTextBuilder builder = DefaultLoadMoreTextBuilder.english}) {
    String text = builder(status);

    if (status == LoadMoreStatus.fail) {
      return Container(
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.refresh),
            SizedBox(
              width: 10.0,
            ),
            Text('Tap to retry loading reactions.')
          ],
        ),
      );
    }
    if (status == LoadMoreStatus.idle) {
      // No clue why is this even a state.
      return SizedBox();
    }
    if (status == LoadMoreStatus.loading) {
      return Container(
          child: Center(
        child: OBProgressIndicator(),
      ));
    }
    if (status == LoadMoreStatus.nomore) {
      return SizedBox();
    }

    return Text(text);
  }
}