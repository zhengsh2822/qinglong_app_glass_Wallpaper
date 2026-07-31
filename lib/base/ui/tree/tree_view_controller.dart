import 'dart:convert' show jsonDecode, jsonEncode;

import 'models/script_data.dart';

/// Defines the insertion mode adding a new [ScriptData] to the [TreeView].
enum InsertMode {
  prepend,
  append,
  insert,
}

/// Defines the controller needed to display the [TreeView].
///
/// Used by [TreeView] to display the nodes and selected node.
///
/// This class also defines methods used to manipulate data in
/// the [TreeView]. The methods ([addNode], [updateNode],
/// and [deleteNode]) are non-mutilating, meaning they will not
/// modify the tree but instead they will return a mutilated
/// copy of the data. You can then use your own logic to appropriately
/// update the [TreeView]. e.g.
///
/// ```dart
/// TreeViewController controller = TreeViewController(children: nodes);
/// Node node = controller.getNode('unique_key')!;
/// Node updatedNode = node.copyWith(
///   key: 'another_unique_key',
///   label: 'Another Node',
/// );
/// List<Node> newChildren = controller.updateNode(node.key, updatedNode);
/// controller = TreeViewController(children: newChildren);
/// ```
class TreeViewController {
  /// The data for the [TreeView].
  final List<ScriptData> children;

  /// The key of the select node in the [TreeView].
  final String? selectedKey;

  TreeViewController({
    this.children = const [],
    this.selectedKey,
  });

  /// Creates a copy of this controller but with the given fields
  /// replaced with the new values.
  TreeViewController copyWith<T>({List<ScriptData>? children, String? selectedKey}) {
    return TreeViewController(
      children: children ?? this.children,
      selectedKey: selectedKey ?? this.selectedKey,
    );
  }

  /// Loads this controller with data from a JSON String
  /// This method expects the user to properly update the state
  ///
  /// ```dart
  /// setState((){
  ///   controller = controller.loadJSON(json: jsonString);
  /// });
  /// ```
  TreeViewController loadJSON<T>({String json = '[]'}) {
    List jsonList = jsonDecode(json);
    List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(jsonList);
    return loadMap<T>(list: list);
  }

  /// Loads this controller with data from a Map.
  /// This method expects the user to properly update the state
  ///
  /// ```dart
  /// setState((){
  ///   controller = controller.loadMap(map: dataMap);
  /// });
  /// ```
  TreeViewController loadMap<T>({List<Map<String, dynamic>> list = const []}) {
    List<ScriptData> treeData =
        list.map((Map<String, dynamic> item) => ScriptData.fromMap(item)).toList();
    return TreeViewController(
      children: treeData,
      selectedKey: selectedKey,
    );
  }

  /// Adds a new node to an existing node identified by specified key.
  /// It returns a new controller with the new node added. This method
  /// expects the user to properly place this call so that the state is
  /// updated.
  ///
  /// See [TreeViewController.addNode] for info on optional parameters.
  ///
  /// ```dart
  /// setState((){
  ///   controller = controller.withAddNode(key, newNode);
  /// });
  /// ```
  TreeViewController withAddNode(
    String key,
    ScriptData newNode, {
    ScriptData? parent,
    int? index,
    InsertMode mode = InsertMode.append,
  }) {
    List<ScriptData> data =
        addNode(key, newNode, parent: parent, mode: mode, index: index);
    return TreeViewController(
      children: data,
      selectedKey: selectedKey,
    );
  }

  /// Replaces an existing node identified by specified key with a new node.
  /// It returns a new controller with the updated node replaced. This method
  /// expects the user to properly place this call so that the state is
  /// updated.
  ///
  /// See [TreeViewController.updateNode] for info on optional parameters.
  ///
  /// ```dart
  /// setState((){
  ///   controller = controller.withUpdateNode(key, newNode);
  /// });
  /// ```
  TreeViewController withUpdateNode(String key, ScriptData newNode, {ScriptData? parent}) {
    List<ScriptData> data = updateNode(key, newNode, parent: parent);
    return TreeViewController(
      children: data,
      selectedKey: selectedKey,
    );
  }

  /// Removes an existing node identified by specified key.
  /// It returns a new controller with the node removed. This method
  /// expects the user to properly place this call so that the state is
  /// updated.
  ///
  /// See [TreeViewController.deleteNode] for info on optional parameters.
  ///
  /// ```dart
  /// setState((){
  ///   controller = controller.withDeleteNode(key);
  /// });
  /// ```
  TreeViewController withDeleteNode(String key, {ScriptData? parent}) {
    List<ScriptData> data = deleteNode(key, parent: parent);
    return TreeViewController(
      children: data,
      selectedKey: selectedKey,
    );
  }

  /// Toggles the expanded property of an existing node identified by
  /// specified key. It returns a new controller with the node toggled.
  /// This method expects the user to properly place this call so
  /// that the state is updated.
  ///
  /// See [TreeViewController.toggleNode] for info on optional parameters.
  ///
  /// ```dart
  /// setState((){
  ///   controller = controller.withToggleNode(key, newNode);
  /// });
  /// ```
  TreeViewController withToggleNode(String key, {ScriptData? parent}) {
    List<ScriptData> data = toggleNode(key, parent: parent);
    return TreeViewController(
      children: data,
      selectedKey: selectedKey,
    );
  }

  /// Expands all nodes down to Node identified by specified key.
  /// It returns a new controller with the nodes expanded.
  /// This method expects the user to properly place this call so
  /// that the state is updated.
  ///
  /// Internally uses [TreeViewController.expandToNode].
  ///
  /// ```dart
  /// setState((){
  ///   controller = controller.withExpandToNode(key, newNode);
  /// });
  /// ```
  TreeViewController withExpandToNode(String key) {
    List<ScriptData> data = expandToNode(key);
    return TreeViewController(
      children: data,
      selectedKey: selectedKey,
    );
  }

  /// Collapses all nodes down to Node identified by specified key.
  /// It returns a new controller with the nodes collapsed.
  /// This method expects the user to properly place this call so
  /// that the state is updated.
  ///
  /// Internally uses [TreeViewController.collapseToNode].
  ///
  /// ```dart
  /// setState((){
  ///   controller = controller.withCollapseToNode(key, newNode);
  /// });
  /// ```
  TreeViewController withCollapseToNode(String key) {
    List<ScriptData> data = collapseToNode(key);
    return TreeViewController(
      children: data,
      selectedKey: selectedKey,
    );
  }

  /// Expands all nodes down to parent Node.
  /// It returns a new controller with the nodes expanded.
  /// This method expects the user to properly place this call so
  /// that the state is updated.
  ///
  /// Internally uses [TreeViewController.expandAll].
  ///
  /// ```dart
  /// setState((){
  ///   controller = controller.withExpandAll();
  /// });
  /// ```
  TreeViewController withExpandAll({ScriptData? parent}) {
    List<ScriptData> data = expandAll(parent: parent);
    return TreeViewController(
      children: data,
      selectedKey: selectedKey,
    );
  }

  /// Collapses all nodes down to parent Node.
  /// It returns a new controller with the nodes collapsed.
  /// This method expects the user to properly place this call so
  /// that the state is updated.
  ///
  /// Internally uses [TreeViewController.collapseAll].
  ///
  /// ```dart
  /// setState((){
  ///   controller = controller.withCollapseAll();
  /// });
  /// ```
  TreeViewController withCollapseAll({ScriptData? parent}) {
    List<ScriptData> data = collapseAll(parent: parent);
    return TreeViewController(
      children: data,
      selectedKey: selectedKey,
    );
  }

  /// Gets the node that has a key value equal to the specified key.
  ScriptData? getNode(String key, {ScriptData? parent}) {
    ScriptData? found;
    List<ScriptData> children = parent == null ? this.children : parent.children;
    Iterator iter = children.iterator;
    while (iter.moveNext()) {
      ScriptData child = iter.current;
      if (child.key == key) {
        found = child;
        break;
      } else {
        if (child.isParent) {
          found = getNode(key, parent: child);
          if (found != null) {
            break;
          }
        }
      }
    }
    return found;
  }

  /// Expands all node that are children of the parent node parameter. If no parent is passed, uses the root node as the parent.
  List<ScriptData> expandAll({ScriptData? parent}) {
    List<ScriptData> children = [];
    Iterator iter =
        parent == null ? children.iterator : parent.children.iterator;
    while (iter.moveNext()) {
      ScriptData child = iter.current;
      if (child.isParent) {
        children.add(child.copyWith(
          expanded: true,
          children: expandAll(parent: child),
        ));
      } else {
        children.add(child);
      }
    }
    return children;
  }

  /// Collapses all node that are children of the parent node parameter. If no parent is passed, uses the root node as the parent.
  List<ScriptData> collapseAll({ScriptData? parent}) {
    List<ScriptData> children = [];
    Iterator iter =
        parent == null ? children.iterator : parent.children.iterator;
    while (iter.moveNext()) {
      ScriptData child = iter.current;
      if (child.isParent) {
        children.add(child.copyWith(
          expanded: false,
          children: collapseAll(parent: child),
        ));
      } else {
        children.add(child);
      }
    }
    return children;
  }

  /// Gets the parent of the node identified by specified key.
  ScriptData? getParent(String key, {ScriptData? parent}) {
    ScriptData? found;
    List<ScriptData> children = parent == null ? this.children : parent.children;
    Iterator iter = children.iterator;
    while (iter.moveNext()) {
      ScriptData child = iter.current;
      if (child.key == key) {
        found = parent ?? child;
        break;
      } else {
        if (child.isParent) {
          found = getParent(key, parent: child);
          if (found != null) {
            break;
          }
        }
      }
    }
    return found == null ? null : found;
  }

  /// Expands a node and all of the node's ancestors so that the node is
  /// visible without the need to manually expand each node.
  List<ScriptData> expandToNode(String key) {
    List<String> ancestors = [];
    String currentKey = key;

    ancestors.add(currentKey);

    ScriptData? parent = getParent(currentKey);
    if (parent != null) {
      while (parent!.key != currentKey) {
        currentKey = parent.key;
        ancestors.add(currentKey);
        parent = getParent(currentKey);
      }
      TreeViewController controller = this;
      ancestors.forEach((String k) {
        ScriptData node = controller.getNode(k)!;
        ScriptData updated = node.copyWith(expanded: true);
        controller = controller.withUpdateNode(k, updated);
      });
      return controller.children;
    }
    return children;
  }

  /// Collapses a node and all of the node's ancestors without the need to
  /// manually collapse each node.
  List<ScriptData> collapseToNode(String key) {
    List<String> ancestors = [];
    String currentKey = key;

    ancestors.add(currentKey);

    ScriptData? parent = getParent(currentKey);
    if (parent != null) {
      while (parent!.key != currentKey) {
        currentKey = parent.key;
        ancestors.add(currentKey);
        parent = getParent(currentKey);
      }
      TreeViewController controller = this;
      ancestors.forEach((String k) {
        ScriptData node = controller.getNode(k)!;
        ScriptData updated = node.copyWith(expanded: false);
        controller = controller.withUpdateNode(k, updated);
      });
      return controller.children;
    }
    return children;
  }

  /// Adds a new node to an existing node identified by specified key. It optionally
  /// accepts an [InsertMode] and index. If no [InsertMode] is specified,
  /// it appends the new node as a child at the end. This method returns
  /// a new list with the added node.
  List<ScriptData> addNode(
    String key,
    ScriptData newNode, {
    ScriptData? parent,
    int? index,
    InsertMode mode = InsertMode.append,
  }) {
    List<ScriptData> _children0 = parent == null ? children : parent.children;
    return _children0.map((ScriptData child) {
      if (child.key == key) {
        List<ScriptData> children = child.children.toList(growable: true);
        if (mode == InsertMode.prepend) {
          children.insert(0, newNode);
        } else if (mode == InsertMode.insert) {
          children.insert(index ?? children.length, newNode);
        } else {
          children.add(newNode);
        }
        return child.copyWith(children: children);
      } else {
        return child.copyWith(
          children: addNode(
            key,
            newNode,
            parent: child,
            mode: mode,
            index: index,
          ),
        );
      }
    }).toList();
  }

  /// Updates an existing node identified by specified key. This method
  /// returns a new list with the updated node.
  List<ScriptData> updateNode(String key, ScriptData newNode, {ScriptData? parent}) {
    List<ScriptData> children = parent == null ? this.children : parent.children;
    return children.map((ScriptData child) {
      if (child.key == key) {
        return newNode;
      } else {
        if (child.isParent) {
          return child.copyWith(
            children: updateNode(
              key,
              newNode,
              parent: child,
            ),
          );
        }
        return child;
      }
    }).toList();
  }

  /// Toggles an existing node identified by specified key. This method
  /// returns a new list with the specified node toggled.
  List<ScriptData> toggleNode(String key, {ScriptData? parent}) {
    ScriptData? node = getNode(key, parent: parent);
    return updateNode(key, node!.copyWith(expanded: !node.expanded));
  }

  /// Deletes an existing node identified by specified key. This method
  /// returns a new list with the specified node removed.
  List<ScriptData> deleteNode(String key, {ScriptData? parent}) {
    List<ScriptData> children = parent == null ? this.children : parent.children;
    List<ScriptData> filteredChildren = [];
    Iterator iter = children.iterator;
    while (iter.moveNext()) {
      ScriptData child = iter.current;
      if (child.key != key) {
        if (child.isParent) {
          filteredChildren.add(child.copyWith(
            children: deleteNode(key, parent: child),
          ));
        } else {
          filteredChildren.add(child);
        }
      }
    }
    return filteredChildren;
  }

  /// Get the current selected node. Returns null if there is no selectedKey
  ScriptData? get selectedNode {
    return selectedKey!.isEmpty ? null : getNode(selectedKey!);
  }



  @override
  String toString() {
    return "";
  }
}
