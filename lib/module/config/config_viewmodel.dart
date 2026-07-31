import 'package:flutter/cupertino.dart';
import 'package:qinglong_app/base/base_viewmodel.dart';
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/main.dart';
import 'package:qinglong_app/module/config/config_bean.dart';

class ConfigViewModel extends BaseViewModel {
  List<ConfigBean> list = [];

  @override
  void retry(BuildContext context, {bool showLoading = true}) {
    loadData(context, showLoading);
  }

  Future<void> loadData(BuildContext context, [isLoading = true]) async {
    if (isLoading && list.isEmpty) {
      loading(notify: true);
    }

    HttpResponse<List<ConfigBean>> result =
        await SingleAccountPageState.ofApi(context).files();

    if (result.success && result.bean != null) {
      list.clear();
      list.addAll(result.bean!);
      success();
    } else {
      list.clear();
      failed(result.message, notify: true);
    }
  }
}
