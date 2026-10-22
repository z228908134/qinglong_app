import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/routes.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/ui/loading_widget.dart';
import 'package:qinglong_app/base/ui/search_cell.dart';
import 'package:qinglong_app/base/ui/tree/models/script_data.dart';
import 'package:qinglong_app/module/others/scripts/folder_add_page.dart';
import 'package:qinglong_app/module/others/scripts/script_upload_page.dart';
import 'package:qinglong_app/utils/extension.dart';

import '../../../base/cupertino_sheet.dart';
import '../../../base/ui/tree/tree_view.dart';
import '../../../base/ui/tree/tree_view_controller.dart';
import '../../../main.dart';
import '../../home/system_bean.dart';

class ScriptPage extends ConsumerStatefulWidget {
  const ScriptPage({Key? key}) : super(key: key);

  @override
  _ScriptPageState createState() => _ScriptPageState();
}

class _ScriptPageState extends ConsumerState<ScriptPage> with LazyLoadState<ScriptPage> {
  List<ScriptData> list = [];

  String? path;

  ScrollController controller = ScrollController();
  TextEditingController searchText = TextEditingController();

  bool buttonshow = false;

  void scrollToTop() {
    controller.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.linear);
  }

  @override
  void initState() {
    super.initState();
    controller.addListener(floatingButtonVisibility);
    searchText.addListener(() {
      setState(() {});
    });
  }

  void floatingButtonVisibility() {
    double y = controller.offset;
    if (y > 500) {
      if (buttonshow == true) return;
      setState(() {
        buttonshow = true;
      });
    } else {
      if (buttonshow == false) return;
      setState(() {
        buttonshow = false;
      });
    }
  }

  late TreeViewController _treeViewController;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: (_) {
        FocusScope.of(context).requestFocus(FocusNode());
      },
      child: Scaffold(
        floatingActionButton: Visibility(
          visible: buttonshow,
          child: FloatingActionButton(
            mini: true,
            onPressed: () {
              scrollToTop();
            },
            elevation: 2,
            child: const Icon(CupertinoIcons.up_arrow),
          ),
        ),
        appBar: QlAppBar(
          canBack: true,
          backCall: () {
            Navigator.of(context).pop();
          },
          title: "脚本管理",
          actions: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                showMoreOperate(
                  context,
                  [
                    CupertinoSheer(
                      title: "新增文件",
                      onTap: () {
                        addScript();
                      },
                    ),
                    addDivider(),
                    CupertinoSheer(
                      title: "新增文件夹",
                      onTap: () {
                        SystemBean? systemBean;
                        try {
                          systemBean = getIt<SystemBean>(instanceName: (SingleAccountPageState.of(context)?.index ?? 0).toString());
                        } catch (e) {
                          systemBean = SystemBean(version: "2.10.13", fromAutoGet: false);
                        }
                        if (!systemBean.isUpperVersion2_14_5()) {
                          "该功能仅支持v2.14.5及以上版本".toast();
                          return;
                        }
                        addFloder();
                      },
                    )
                  ],
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 15,
                ),
                child: Center(
                  child: Icon(
                    CupertinoIcons.add,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: list.isEmpty
            ? const Center(
                child: LoadingWidget(),
              )
            : Column(
                children: [
                  searchCell(ref),
                  Expanded(
                    child: RefreshIndicator(
                      color: Theme.of(context).primaryColor,
                      onRefresh: () async {
                        await loadData();
                        return Future.value();
                      },
                      child: isSearching
                          ? buildSearchResult()
                          : TreeView(
                              controller: _treeViewController,
                              onExpansionChanged: (key, state) {
                                ScriptData? node = _treeViewController.getNode(key);
                                if (node != null) {
                                  List<ScriptData> updated = _treeViewController.updateNode(
                                    key,
                                    node.copyWith(expanded: !node.expanded),
                                  );
                                  setState(() {
                                    _treeViewController = _treeViewController.copyWith(children: updated);
                                  });
                                }
                              },
                              onDeleteSelfClick: (ScriptData data) {
                                showCupertinoDialog(
                                  useRootNavigator: false,
                                  context: context,
                                  builder: (context1) => CupertinoAlertDialog(
                                    title: const Text("确认删除"),
                                    content: const Text("确认删除吗"),
                                    actions: [
                                      CupertinoDialogAction(
                                        child: const Text(
                                          "取消",
                                          style: TextStyle(
                                            color: Color(0xff999999),
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                      CupertinoDialogAction(
                                        child: Text(
                                          "确定",
                                          style: TextStyle(
                                            color: ref.watch(themeProvider).primaryColor,
                                          ),
                                        ),
                                        onPressed: () async {
                                          Navigator.of(context1).pop();
                                          deleteFold(data);
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                              onNodeTap: (key) {
                                ScriptData? selectedNode = _treeViewController.getNode(key);
                                openScript(selectedNode?.title, selectedNode?.parent);
                              },
                            ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void openScript(String? title, String? parent) {
    FocusScope.of(context).requestFocus(FocusNode());
    Navigator.of(context)
        .pushNamed(
      Routes.routeScriptDetail,
      arguments: {
        "title": title,
        "path": parent,
      },
    )
        .then(
      (value) {
        if (value != null && value == true) {
          loadData();
        }
      },
    );
  }

  Widget searchCell(WidgetRef context) {
    return Container(
      color: ref.watch(themeProvider).themeColor.searchBgColor(),
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 10,
      ),
      child: SearchCell(
        controller: searchText,
      ),
    );
  }

  String get keyword => searchText.text.trim();

  bool get isSearching => keyword.isNotEmpty;

  /// 递归摊平脚本树，得到全部文件节点
  List<ScriptData> getAllFiles() {
    List<ScriptData> files = [];
    void walk(List<ScriptData> nodes) {
      for (ScriptData node in nodes) {
        if (node.isParent) {
          walk(node.children);
        } else if (node.title.isNotEmpty) {
          files.add(node);
        }
      }
    }

    walk(list);
    return files;
  }

  List<ScriptData> get searchResultList {
    String kw = keyword.toLowerCase();
    List<ScriptData> result = getAllFiles().where((element) {
      return element.title.toLowerCase().contains(kw) || element.parent.toLowerCase().contains(kw);
    }).toList();
    // 文件名完全匹配 / 前缀匹配的排前面
    result.sort((a, b) {
      int scoreA = _matchScore(a, kw);
      int scoreB = _matchScore(b, kw);
      if (scoreA != scoreB) return scoreB.compareTo(scoreA);
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return result;
  }

  int _matchScore(ScriptData data, String kw) {
    String title = data.title.toLowerCase();
    if (title == kw) return 3;
    if (title.startsWith(kw)) return 2;
    if (title.contains(kw)) return 1;
    return 0;
  }

  Widget buildSearchResult() {
    List<ScriptData> result = searchResultList;
    if (result.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 120,
          ),
          Center(
            child: Text(
              "没有找到包含「$keyword」的脚本",
              style: TextStyle(
                fontSize: 14,
                color: ref.watch(themeProvider).themeColor.descColor(),
              ),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(
        bottom: 20,
      ),
      itemCount: result.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Container(
            padding: const EdgeInsets.fromLTRB(15, 10, 15, 6),
            child: Text(
              "找到 ${result.length} 个脚本",
              style: TextStyle(
                fontSize: 12,
                color: ref.watch(themeProvider).themeColor.descColor(),
              ),
            ),
          );
        }
        return searchResultCell(result[index - 1]);
      },
    );
  }

  Widget searchResultCell(ScriptData data) {
    ThemeColors themeColor = ref.watch(themeProvider).themeColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        openScript(data.title, data.parent);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: themeColor.settingBordorColor(),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.doc_text,
              size: 20,
              color: themeColor.descColor(),
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    buildHighlightText(
                      data.title,
                      keyword,
                      themeColor.titleColor(),
                      ref.watch(themeProvider).primaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Text.rich(
                    buildHighlightText(
                      (data.parent.isEmpty || data.parent == "/") ? "根目录" : "/${data.parent}",
                      keyword,
                      themeColor.descColor(),
                      ref.watch(themeProvider).primaryColor,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_forward,
              size: 16,
              color: themeColor.descColor(),
            ),
          ],
        ),
      ),
    );
  }

  /// 把命中的关键字标红高亮
  TextSpan buildHighlightText(
    String text,
    String kw,
    Color normalColor,
    Color highlightColor, {
    double fontSize = 16,
  }) {
    TextStyle normal = TextStyle(
      fontSize: fontSize,
      color: normalColor,
    );
    if (kw.isEmpty) {
      return TextSpan(text: text, style: normal);
    }
    TextStyle highlight = TextStyle(
      fontSize: fontSize,
      color: highlightColor,
      fontWeight: FontWeight.w600,
    );
    String lowerText = text.toLowerCase();
    String lowerKw = kw.toLowerCase();
    List<TextSpan> spans = [];
    int start = 0;
    while (start < text.length) {
      int index = lowerText.indexOf(lowerKw, start);
      if (index < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + kw.length),
        style: highlight,
      ));
      start = index + kw.length;
    }
    return TextSpan(style: normal, children: spans);
  }

  Future<void> loadData() async {
    HttpResponse<List<ScriptData>> response = await SingleAccountPageState.ofApi(context).scripts();

    if (response.success) {
      if (response.bean == null || response.bean!.isEmpty) {
        "暂无数据".toast();
      }
      list.clear();
      response.bean?.removeWhere((element) => element.title == "node_modules");
      list.addAll(response.bean ?? []);
      _treeViewController = TreeViewController(children: list);
      setState(() {});
    } else {
      response.message?.toast();
    }
  }

  @override
  void onLazyLoad() {
    loadData();
  }

  String scriptPath = "";

  void addScript() {
    Navigator.of(context)
        .push(
      CupertinoPageRoute(
        builder: (context) => const ScriptUploadPage(),
      ),
    )
        .then((value) {
      if (value != null && value == true) {
        loadData();
      }
    });
  }

  void addFloder() {
    Navigator.of(context)
        .push(
      CupertinoPageRoute(
        builder: (context) => const FloderAddPage(),
      ),
    )
        .then((value) {
      if (value != null && value == true) {
        loadData();
      }
    });
  }

  void deleteFold(ScriptData item) async {
    SystemBean? systemBean;

    try {
      systemBean = getIt<SystemBean>(instanceName: (SingleAccountPageState.of(context)?.index ?? 0).toString());
    } catch (e) {
      systemBean = SystemBean(version: "2.10.13", fromAutoGet: false);
    }
    if ((item.children.isNotEmpty) && !systemBean.isUpperVersion2_14_5()) {
      "该功能仅支持v2.14.5及以上版本".toast();
      return;
    }

    EasyLoading.show(status: "删除中...");
    var temp = (item.type == "directory")
        ? await SingleAccountPageState.ofApi(context).delScriptFold(
            item.title,
            item.parent,
          )
        : (systemBean.isUpperVersion2_14_5()
            ? await SingleAccountPageState.ofApi(context).delScriptNewVersion(
                item.title,
                item.parent,
              )
            : await SingleAccountPageState.ofApi(context).delScript(
                item.title,
                item.parent,
              ));
    EasyLoading.dismiss();
    if (temp.success) {
      "已删除".toast();
      await loadData();
    } else {
      temp.message.toast();
    }
  }
}
