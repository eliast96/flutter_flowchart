import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:graphite/graphite.dart';
import 'package:intl/intl.dart' as intl;
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:tuple/tuple.dart';
import 'flowchart.dart';

enum FlowDisplayType { flow, displayOnly, select }

enum FlowNodeStatus { inProgress, completed, skipped, blocked }

final dateOutputFormat = intl.DateFormat('dd/MM/yyyy');

const int defaultDaysToFinish = 7;

class CircularPathResponse {
  final bool isFound;
  final FlowchartNode? duplicate;
  final bool? isFollowUps;
  final List<FlowchartNode>? circularPath;

  const CircularPathResponse({
    required this.isFound,
    this.isFollowUps,
    this.duplicate,
    this.circularPath,
  });
}

class FlowchartGraph extends StatefulWidget {
  final List<FlowchartNode> nodes;
  final List<FlowchartNode> predefinedTasks;

  // A function that is called when a task status is changed
  // The first parameter is the id of the task that was completed
  // The second parameter is the new status
  // The third parameter is a list of the nodes that were updated in the graph
  final Function({
    required String id,
    required FlowNodeStatus newStatus,
    required List<FlowchartNode> updatedNodes,
  }) onTaskStatusChanged;

  // A function that is called when a task is completed
  // The first parameter is the id of the task that was completed
  // The second parameter is a list of the nodes that were updated in the graph
  final Function({
    required String id,
    required List<FlowchartNode> updatedNodes,
  }) onTaskCompleted;

  // A function that is called when a task is deleted
  // The first parameter is the id of the task that was deleted
  // The second parameter is a list of the nodes that were updated in the graph
  final Function({
    required String id,
    required List<FlowchartNode> updatedNodes,
  }) onTaskDeleted;

  // A function that is called when a depend on link is removed from a node
  // The first parameter is the id of the task
  // The second parameter is the id of the depends on link that was removed
  final Function({
    required String id,
    required String dependsOnId,
  }) onRemoveDependOnLink;

  // A function that is called when a depend on link is removed from a node
  // The first parameter is the id of the task
  // The second parameter is the id of the follow up that was removed
  final Function({
    required String id,
    required String followupId,
  }) onRemoveFollowUpLink;

  // A function that is called when a one of the decision links is removed from a decision node
  // The first parameter is the id of the task
  // The second parameter is the name of the decision link that was removed
  final Function({
    required String id,
    required String name,
  }) onRemoveDecisionLink;

  // A function that is called when a new decision option is added to a decision node
  // The first parameter is the id of the task
  // The second parameter is the name of the decision link that was removed
  // The third parameter is the ID of the followup task for this decision
  final Function({
    required String id,
    required String name,
    required String followupPredefinedTaskId,
  }) onAddDecisionLink;

  // A function that is called when a decision question text is updated
  // The first parameter is the id of the updated task's decision
  // The second parameter is the new question text
  final Function({
    required String id,
    required String newQuestion,
  }) onChangeDecisionQuestion;

  // A function that is called when a task follow up is converted from a decision to normal followup(s)
  // The parameter is the id of the task followed by the decision node
  final Function({required String taskId}) onRemoveDecisionNode;

  // A function that is called when a follow up of a task is converted to a decision
  // The first parameter is the id of the task which follow up is converted to decision
  // The second parameter is the question of the decision
  // The third parameter is the answers of the decision as map with random id as key and answer as value
  // The fourth parameter is the follow up ids for each answer (same keys as answers)
  final Function({
    required String taskId,
    required String question,
    required Map answers,
    required Map followupIDs,
  }) onConvertFollowupToDecision;

  // A function that is called when something in the graph is updated (link added/removed)
  // Receives the list of nodes that were updated in the graph
  final Function({required FlowchartNode updatedNode}) onTaskDetailsUpdated;

  // A function that is called when the flow is completed
  final Function? onFlowCompleted;

  // // A function that is called when the "depends on" tasks for a predefined task are requested
  // final List<FlowchartNode> Function({
  //   required String predefinedTaskId,
  // }) onGetPredefinedTaskDependsOn;

  // // A function that is called when the "follow up" tasks for a predefined task are requested
  // final List<FlowchartNode> Function({
  //   required String predefinedTaskId,
  // }) onGetPredefinedTaskFollowUps;

  // A function that is called when a "follow up" dependency is added
  // The first parameter is the id of the task that is being updated
  // The second parameter is a list of the follow up nodes that are being added
  final Function({
    required String id,
    required List<FlowchartNode> followUpNodes,
  }) onAddFollowUpDependency;

  // A function that is called when a "follow up" dependency is added
  // The first parameter is the id of the task that is being updated
  // The second parameter is a list of the follow up nodes that are being added
  final Function({
    required String id,
    required List<FlowchartNode> dependsOnNodes,
  }) onAddDependsOnDependency;

  // A function that is called when a task is added
  final Function({
    required String label,
    required String description,
    required DateTime dueDate,
    required FlowNodeStatus status,
    int? daysToFinish,
  }) onSingleTaskAdded;

  // A function that is called when predefined tasks are added
  // The first parameter is a list of the predefined task ids that were added
  final Function({
    required List<String> predefinedTaskIds,
  }) onPredefinedTasksAdded;

  final FlowDisplayType displayType;

  FlowchartGraph({
    required this.nodes, // currentPredefinedTasks
    required this.predefinedTasks, // all predefined tasks
    required this.onTaskStatusChanged,
    required this.onTaskCompleted,
    required this.onTaskDeleted,
    required this.onTaskDetailsUpdated,
    required this.displayType,
    required this.onSingleTaskAdded,
    required this.onPredefinedTasksAdded,
    required this.onAddDecisionLink,
    required this.onRemoveDecisionLink,
    required this.onRemoveDependOnLink,
    required this.onConvertFollowupToDecision,
    required this.onRemoveDecisionNode,
    required this.onRemoveFollowUpLink,
    required this.onAddFollowUpDependency,
    required this.onAddDependsOnDependency,
    required this.onChangeDecisionQuestion,
    this.onFlowCompleted,
  });

  @override
  State<FlowchartGraph> createState() => _FlowchartGraphState();
}

class _FlowchartGraphState extends State<FlowchartGraph> {
  final List<NodeInput> _flowChart = [];
  final Map<String, Map<String, List<String>>> _combDependencies = {};
  final Map<String, FlowStep> _nodes = {};

  bool _isLoadingChart = false;

  @override
  void initState() {
    super.initState();
    _buildGraph();
  }

  void _buildGraph() {
    setState(() {
      _isLoadingChart = true;
    });
    _nodes.clear();
    _flowChart.clear();
    _combDependencies.clear();
    Map<String, List<EdgeInput>> nextNodes = {};
    List<String> decisionTasks = [];
    for (var p in widget.nodes) {
      nextNodes[p.id] = [];
      if (p.isFollowedByDecision) {
        nextNodes["${p.id}__FOLLOWUP"] = [];
      }
    }
    for (var p in widget.nodes) {
      var curTaskFollowups = p.followupNodes;
      var followupsIds = curTaskFollowups.map((e) => e.id).toList();
      var curTaskDependson = p.dependsOnNodes;
      var dependsonIds = curTaskDependson.map((e) => e.id).toList();
      var curTaskDecisions = p.decisionNodes;
      var decisionsIds =
          curTaskDecisions?.map((e) => e.followupNodeId).toList();
      decisionTasks.addAll(decisionsIds ?? []);

      _combDependencies[p.id] = {
        'DependsOn': dependsonIds,
        'FollowUps': p.isFollowedByDecision ? decisionsIds! : followupsIds,
      };
      _nodes[p.id] = FlowStep(
        text: p.label,
        type: FlowStepType.process,
        isCompleted: p.isCompleted,
        isSkipped: p.isSkipped,
        canProgress: false, // Will be determined later
      );
      if (p.isFollowedByDecision) {
        followupsIds = decisionsIds!;
        _nodes["${p.id}__FOLLOWUP"] = FlowStep(
          text: p.decisionQuestion!,
          type: FlowStepType.decision,
          isCompleted: false,
          isSkipped: false,
          canProgress: false,
        );
        nextNodes[p.id]!.add(
          EdgeInput(
            outcome: "${p.id}__FOLLOWUP",
          ),
        );
      }
      nextNodes[p.isFollowedByDecision ? "${p.id}__FOLLOWUP" : p.id]!.addAll(
        followupsIds.map(
          (e) => EdgeInput(outcome: e.toString()),
        ),
      );
      for (var t in curTaskDependson) {
        nextNodes[t.id]!.add(EdgeInput(outcome: p.id));
      }
    }

    // Re-order tasks by dependencies
    widget.nodes.sort((task1, task2) {
      if ((_combDependencies[task1.id]!['DependsOn']!.isEmpty &&
              _combDependencies[task2.id]!['DependsOn']!.isNotEmpty) ||
          (!decisionTasks.contains(task1.id) &&
              decisionTasks.contains(task2.id)) ||
          (_combDependencies[task1.id]!['FollowUps']!.contains(task2.id) &&
              !_combDependencies[task2.id]!['FollowUps']!.contains(task1.id))) {
        return -1; // task1 should come before task2
      } else if ((_combDependencies[task1.id]!['DependsOn']!.isNotEmpty &&
              _combDependencies[task2.id]!['DependsOn']!.isEmpty) ||
          (decisionTasks.contains(task1.id) &&
              !decisionTasks.contains(task2.id)) ||
          (!_combDependencies[task1.id]!['FollowUps']!.contains(task2.id) &&
              _combDependencies[task2.id]!['FollowUps']!.contains(task1.id))) {
        return 1; // task2 should come before task1
      } else {
        return 0; // keep the relative order unchanged
      }
    });

    for (var e in widget.nodes) {
      _flowChart.add(
        NodeInput(
          id: e.id,
          next: nextNodes[e.id]!,
        ),
      );
      if (e.isFollowedByDecision) {
        _flowChart.add(
          NodeInput(
            id: "${e.id}__FOLLOWUP",
            next: nextNodes["${e.id}__FOLLOWUP"]!,
            size: const NodeSize(
              width: 100,
              height: 100,
            ),
          ),
        );
      }
    }

    // Check which tasks can progress
    if (widget.displayType == FlowDisplayType.flow) {
      _updateGraphProgress();
    }
    setState(() {
      _isLoadingChart = false;
    });
  }

  Future<void> _updateGraphProgress() async {
    List<String> nonCompletedDecisions = [];
    List<String> blockedTasks = [];
    for (var task in widget.nodes) {
      // Check if direct decision options
      if (_combDependencies.keys.any((k) =>
          _combDependencies[k]!['FollowUps']!.contains(task.id) &&
          _flowChart.any((f) => f.id == "${k}__FOLLOWUP") &&
          !widget.nodes.singleWhere((t) => t.id == k).isCompleted)) {
        nonCompletedDecisions.add(task.id);
      } else
      // Check if one of the dependencies is blocked (DependsOn)
      if (_combDependencies[task.id]!['DependsOn']!.any((e) =>
          (!widget.nodes.singleWhere((t) => t.id == e).isCompleted &&
              !widget.nodes.singleWhere((t) => t.id == e).isSkipped) ||
          blockedTasks.contains(e) ||
          nonCompletedDecisions.contains(e))) {
        // The task is blocked
        blockedTasks.add(task.id);

        // Check if part of uncompleted decision
        if (_combDependencies[task.id]!['DependsOn']!
                .any((e) => nonCompletedDecisions.contains(e)) ||
            _combDependencies.keys.any((k) =>
                _combDependencies[k]!['FollowUps']!.contains(task.id) &&
                nonCompletedDecisions.contains(k))) {
          nonCompletedDecisions.add(task.id);
        }
      } else // Check if one of the dependencies is blocked (FollowUps)
      if (_combDependencies.keys.any((k) =>
          _combDependencies[k]!['FollowUps']!.contains(task.id) &&
          !widget.nodes.singleWhere((t) => t.id == k).isFollowedByDecision &&
          !widget.nodes.singleWhere((t) => t.id == k).isCompleted &&
          !widget.nodes.singleWhere((t) => t.id == k).isSkipped)) {
        blockedTasks.add(task.id);
      } else {
        // Task can be completed
        _nodes[task.id]!.canProgress = true;

        if (task.dueDate == null && !task.isSkipped) {
          debugPrint("Updating Doable Task DueDate...");
          task.dueDate = DateTime.now()
              .add(Duration(days: task.daysToFinish ?? defaultDaysToFinish));
          // var updatedTask = await patchTask(
          //   id: task.ID,
          //   updates: {"DueDate": task.DueDate!.toIso8601String()},
          // );
          // await dbProvider.updateTask(id: task.ID, newVal: updatedTask);
          await widget.onTaskStatusChanged(
            id: task.id,
            newStatus: FlowNodeStatus.inProgress,
            updatedNodes: [task],
          );
        }
      }
    }

    // if tasks were open and now blocked by dependenices --> reset due date
    var resetDueDate = widget.nodes
        .where((t) => t.dueDate != null && _nodes[t.id]!.canProgress == false)
        .toList();
    for (var resetTask in resetDueDate) {
      resetTask.dueDate = null;
      // await updateTask(id: resetTask.ID, updatedTask: resetTask);
      // await dbProvider.updateTask(id: resetTask.ID, newVal: resetTask);
      await widget.onTaskStatusChanged(
        id: resetTask.id,
        newStatus: FlowNodeStatus.blocked,
        updatedNodes: [resetTask],
      );
    }

    if (_getIsFlowCompleted()) {
      await widget.onFlowCompleted?.call();
      debugPrint("Flow Completed!");
    }
  }

  FlowchartNode? getNodeById(String id) {
    try {
      return widget.nodes.singleWhere((node) => node.id == id);
    } catch (e) {
      return null;
    }
  }

  // Flowchart getFlowchart({FlowDisplayType type = FlowDisplayType.flow}) {
  bool _getIsFlowCompleted() {
    return widget.nodes.every((node) => node.isCompleted || node.isSkipped);
  }

  void _showDatePicker(
    TextEditingController taskDueDateController,
    TextEditingController daysToFinishController,
  ) {
    showDatePicker(
      context: context,
      // in future will change according to chosen app language
      locale: Localizations.localeOf(context),
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    ).then((date) {
      if (date == null) {
        return;
      }

      var outputDate = dateOutputFormat.format(date);
      taskDueDateController.text = outputDate;
      daysToFinishController.text =
          date.difference(DateTime.now()).inDays.toString();
    });
  }

  Future<void> _markPathSkippedRecursively(FlowchartNode task) async {
    // await patchTask(
    //   id: task.ID,
    //   updates: {
    //     "Status": Strings.taskSkipped,
    //   },
    // );
    task.status = FlowNodeStatus.skipped;
    _nodes[task.id]!.isSkipped = true;
    // await dbProvider.updateTask(id: task.ID, newVal: task);
    await widget.onTaskStatusChanged(
      id: task.id,
      newStatus: FlowNodeStatus.skipped,
      updatedNodes: [task],
    );

    var dependants = _combDependencies.keys
        .where((k) =>
            _combDependencies[k]!['DependsOn']!.contains(task.id) &&
            !widget.nodes.singleWhere((e) => e.id == k).isCompleted &&
            !widget.nodes.singleWhere((e) => e.id == k).isSkipped)
        .toList();
    var followups = _combDependencies[task.id]!['FollowUps']!;
    followups.removeWhere((f) =>
        widget.nodes.singleWhere((e) => e.id == f).isCompleted ||
        widget.nodes.singleWhere((e) => e.id == f).isSkipped);
    dependants.addAll(followups);

    for (var d in dependants) {
      var subTask = widget.nodes.singleWhere((t) => t.id == d);
      await _markPathSkippedRecursively(subTask);
    }
  }

  Future<void> _onCompleteTask(String taskID) async {
    setState(() {
      _isLoadingChart = true;
    });

    try {
      var task = widget.nodes.singleWhere((t) => t.id == taskID);
      String? chosenDecision;
      List<FlowchartDecisionNode> decisions = [];
      if (task.isFollowedByDecision) {
        decisions = task.decisionNodes!;
        chosenDecision = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('בחירת החלטה', textAlign: TextAlign.center),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    task.decisionQuestion!,
                    style: const TextStyle(fontSize: 19),
                  ),
                  const SizedBox(height: 20),
                  ...decisions.map(
                    (e) => Padding(
                      padding: const EdgeInsets.all(10),
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(e.answer),
                        style: ElevatedButton.styleFrom(
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(7.0)),
                            side: BorderSide(
                              color: Colors.blue,
                              width: 2,
                            ),
                          ),
                          foregroundColor: Colors.blue,
                        ),
                        child: Text(
                          e.answer,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('ביטול'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
        if (chosenDecision == null) {
          return;
        }
      }

      // await patchTask(
      //   id: taskID,
      //   updates: {
      //     "Status": Strings.taskCompleted,
      //     if (task.IsFollowedByDecision) "ChosenDecision": chosenDecision!,
      //   },
      // );
      task.status = FlowNodeStatus.completed;
      if (task.isFollowedByDecision) {
        task.decisionAnswer = chosenDecision!;
      }

      if (task.isFollowedByDecision) {
        // Mark not-chosen path as Skipped
        for (var decision
            in decisions.where((d) => d.answer != chosenDecision)) {
          var decision_task =
              widget.nodes.singleWhere((t) => t.id == decision.followupNodeId);
          _markPathSkippedRecursively(decision_task);
        }
      }

      // await dbProvider.updateTask(id: taskID, newVal: task);
      _nodes[taskID]!.isCompleted = true;
      await widget.onTaskCompleted(id: taskID, updatedNodes: [task]);
      await _updateGraphProgress();
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      setState(() {
        _isLoadingChart = false;
      });
    }
  }

  Future<void> _onDeleteTask(String taskID) async {
    setState(() {
      _isLoadingChart = true;
    });

    try {
      var currentFollowups = _combDependencies[taskID]!['FollowUps']!;
      var currentParents = _combDependencies.keys
          .where((k) => _combDependencies[k]!['FollowUps']!.contains(taskID));
      List<FlowchartNode> modifiedNodes = [];
      if (currentParents.length == 1) {
        // Only 1 task is pointing to the deleted task as followup,
        // point  it to children instead
        var parentId = currentParents.single;

        // await addTaskFollowups(taskID: parent, followups: currentFollowups);
        // for (var followup in currentFollowups) {
        //   await dbProvider.addTask_FollowUps(
        //     Task_FollowUps(TaskID: parentId, NextID: followup),
        //   );
        // }

        var parentNode = getNodeById(parentId)!;
        parentNode.followupNodes.removeWhere((e) => e.id == taskID);
        parentNode.followupNodes.addAll(
          currentFollowups.map((e) => getNodeById(e)!),
        );

        modifiedNodes.add(parentNode);
      }

      // await deleteTask(id: taskID);
      // await dbProvider.deleteTaskById(id: taskID);
      widget.nodes.removeWhere((e) => e.id == taskID);
      await widget.onTaskDeleted(id: taskID, updatedNodes: modifiedNodes);
      _buildGraph();
    } catch (e) {
      debugPrint(e.toString());
      _showSnackbar(
        context,
        "ארעה שגיאה במחיקת המשימה, אנא נסו שנית מאוחר יותר",
        backgroundColor: Colors.red,
      );
    } finally {
      setState(() {
        _isLoadingChart = false;
      });
    }
  }

  void _showSnackbar(BuildContext context, String message,
      {Color? backgroundColor}) {
    var snackBar = SnackBar(
      content: Text(
        message,
        textAlign: TextAlign.center,
      ),
      backgroundColor: backgroundColor,
    );
    try {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    } catch (snackbarException) {
      debugPrint(snackbarException.toString());
    }
  }

  Future<CircularPathResponse> _checkDependOnCircularPathFromGraph(
    List<FlowchartNode> tasksQueue,
    List<String> idsQueue,
    String newTaskID,
  ) async {
    List<String> dependsOnIDs = _combDependencies[newTaskID]!['DependsOn']!;

    for (String dependOnTaskID in dependsOnIDs) {
      var dependOnTask =
          widget.nodes.singleWhere((e) => e.id == dependOnTaskID);
      // TaskCombination_X_PredefinedTasks dependOnTaskComb =
      //     comb_currentPredefinedTasks
      //         .singleWhere((e) => e.ID == dependOnTaskID);
      // PredefinedTask dependOnTask = _predefinedTasksData
      //     .singleWhere((e) => e.ID == dependOnTaskComb.PredefinedTasksID);

      if (idsQueue.contains(dependOnTaskID)) {
        return CircularPathResponse(
          isFound: true,
          duplicate: dependOnTask,
          isFollowUps: false,
          circularPath: [...tasksQueue, dependOnTask],
        );
      }

      var res = await _checkDependOnCircularPathFromGraph(
        [...tasksQueue, dependOnTask],
        [...idsQueue, dependOnTaskID],
        dependOnTaskID,
      );
      if (res.isFound) {
        return res;
      }
    }

    return const CircularPathResponse(isFound: false);
  }

  Future<CircularPathResponse> _checkFollowUpsCircularPathFromGraph(
    List<FlowchartNode> tasksQueue,
    List<String> idsQueue,
    String newTaskID,
  ) async {
    List<String> followUpIDs = _combDependencies[newTaskID]!['FollowUps']!;
    bool isFollowedByDecision =
        widget.nodes.singleWhere((e) => e.id == newTaskID).isFollowedByDecision;
    List<CircularPathResponse> decisionResponses = [];
    for (String followUpTaskID in followUpIDs) {
      // TaskCombination_X_PredefinedTasks followUpTaskComb =
      //     comb_currentPredefinedTasks
      //         .singleWhere((e) => e.ID == followUpTaskID);
      // PredefinedTask followUpTask = _predefinedTasksData
      //     .singleWhere((e) => e.ID == followUpTaskComb.PredefinedTasksID);
      var followUpTask =
          widget.nodes.singleWhere((e) => e.id == followUpTaskID);

      if (idsQueue.contains(followUpTaskID)) {
        if (isFollowedByDecision) {
          decisionResponses.add(
            CircularPathResponse(
              isFound: true,
              duplicate: followUpTask,
              isFollowUps: true,
              circularPath: [...tasksQueue, followUpTask],
            ),
          );
        } else {
          return CircularPathResponse(
            isFound: true,
            duplicate: followUpTask,
            isFollowUps: true,
            circularPath: [...tasksQueue, followUpTask],
          );
        }
      }

      var res = await _checkFollowUpsCircularPathFromGraph(
        [...tasksQueue, followUpTask],
        [...idsQueue, followUpTaskID],
        followUpTaskID,
      );
      if (res.isFound) {
        if (isFollowedByDecision) {
          decisionResponses.add(res);
        } else {
          return res;
        }
      }
    }

    if (isFollowedByDecision &&
        decisionResponses.isNotEmpty &&
        decisionResponses.length == followUpIDs.length) {
      // If all possible decisions lead to a cycle --> can't add link
      // return one of them as example
      return decisionResponses.first;
    }

    return const CircularPathResponse(isFound: false);
  }

  Future<CircularPathResponse> _checkDependOnCircularPath(
    List<FlowchartNode> tasksQueue,
    List<String> idsQueue,
    FlowchartNode newTask,
  ) async {
    // List<String> dependsOnIDs = (await dbProvider.getAllPredefinedTasks_DependsOn(
    //   predefinedTaskIDFilter: newTask.id,
    // ))
    //     .map((e) => e.DependsOnID)
    //     .toList();
    var dependsOnNodes = widget.predefinedTasks
        .singleWhere((e) => e.id == newTask.id)
        .dependsOnNodes;
    // var dependsOnNodes =
    //     widget.onGetPredefinedTaskDependsOn(predefinedTaskId: newTask.id);

    for (var dependOnTask in dependsOnNodes) {
      if (idsQueue.contains(dependOnTask.id)) {
        return CircularPathResponse(
          isFound: true,
          duplicate: dependOnTask,
          isFollowUps: false,
          circularPath: [...tasksQueue, dependOnTask],
        );
      }

      var res = await _checkDependOnCircularPath(
        [...tasksQueue, dependOnTask],
        [...idsQueue, dependOnTask.id],
        dependOnTask,
      );
      if (res.isFound) {
        return res;
      }
    }

    return const CircularPathResponse(isFound: false);
  }

  Future<CircularPathResponse> _checkFollowupsCircularPath(
    List<FlowchartNode> tasksQueue,
    List<String> idsQueue,
    FlowchartNode newTask,
  ) async {
    // List<int> followUpsIDs = (await dbProvider.getAllPredefinedTasks_FollowUps(
    //   predefinedTaskIDFilter: newTask.ID,
    // ))
    //     .map((e) => e.NextID)
    //     .toList();
    var followUpNodes = widget.predefinedTasks
        .singleWhere((e) => e.id == newTask.id)
        .followupNodes;

    for (var followUpTask in followUpNodes) {
      if (idsQueue.contains(followUpTask.id)) {
        return CircularPathResponse(
          isFound: true,
          duplicate: followUpTask,
          isFollowUps: true,
          circularPath: [...tasksQueue, followUpTask],
        );
      }

      var res = await _checkFollowupsCircularPath(
        [...tasksQueue, followUpTask],
        [...idsQueue, followUpTask.id],
        followUpTask,
      );
      if (res.isFound) {
        return res;
      }
    }

    return const CircularPathResponse(isFound: false);
  }

  Future<CircularPathResponse> _checkNewChunkCircularDependencies(
    List<FlowchartNode> parentTasks,
  ) async {
    for (FlowchartNode predefinedTask in parentTasks) {
      // Create dependencies
      // List<int> dependsOnIDs =
      //     (await dbProvider.getAllPredefinedTasks_DependsOn(
      //   predefinedTaskIDFilter: predefinedTask.ID,
      // ))
      //         .map((e) => e.DependsOnID)
      //         .toList();
      var dependsOnNodes = widget.predefinedTasks
          .singleWhere((e) => e.id == predefinedTask.id)
          .dependsOnNodes;
      // List<int> followUpsIDs =
      //     (await dbProvider.getAllPredefinedTasks_FollowUps(
      //   predefinedTaskIDFilter: predefinedTask.ID,
      // ))
      //         .map((e) => e.NextID)
      //         .toList();
      var followUpNodes = widget.predefinedTasks
          .singleWhere((e) => e.id == predefinedTask.id)
          .followupNodes;

      for (var dependOnTask in dependsOnNodes) {
        if (dependOnTask.id == predefinedTask.id) {
          return CircularPathResponse(
            isFound: true,
            duplicate: predefinedTask,
            isFollowUps: false,
            circularPath: [predefinedTask, predefinedTask],
          );
        }
        // PredefinedTask dependOnTask =
        //     _predefinedTasksData.singleWhere((e) => e.ID == dependOnTaskID);
        var res = await _checkDependOnCircularPath(
          [predefinedTask, dependOnTask],
          [predefinedTask.id, dependOnTask.id],
          dependOnTask,
        );
        if (res.isFound) {
          return res;
        }
      }

      for (var followUpTask in followUpNodes) {
        if (followUpTask.id == predefinedTask.id) {
          return CircularPathResponse(
            isFound: true,
            duplicate: predefinedTask,
            isFollowUps: true,
            circularPath: [predefinedTask, predefinedTask],
          );
        }
        // PredefinedTask followUpTask =
        //     _predefinedTasksData.singleWhere((e) => e.ID == followUpTaskID);

        var res = await _checkFollowupsCircularPath(
          [predefinedTask, followUpTask],
          [predefinedTask.id, followUpTask.id],
          followUpTask,
        );
        if (res.isFound) {
          return res;
        }
      }
    }

    return const CircularPathResponse(isFound: false);
  }

  void _showCircularPathAlert(CircularPathResponse cycleResponse) {
    var path = cycleResponse.circularPath!;
    List<TextSpan> textSpans = [];
    for (var p in path) {
      if (p.id == cycleResponse.duplicate!.id) {
        textSpans.add(
          TextSpan(
            text: p.label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      } else {
        textSpans.add(
          TextSpan(
            text: p.label,
            style: const TextStyle(fontSize: 18),
          ),
        );
      }

      textSpans.add(
        const TextSpan(
          text: "  --->  ",
          style: TextStyle(fontSize: 18),
        ),
      );
    }
    textSpans.removeLast();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('שגיאה: לא ניתן להוסיף תלות'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "הוספת הקשר שבחרת יגרום ליצירת מעגל בגרף:",
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              RichText(
                textAlign: TextAlign.right,
                text: TextSpan(
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontFamily: 'Rubik',
                  ),
                  children: textSpans,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "הקשר לא נוסף.",
                style: TextStyle(fontSize: 18),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('סגור'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Iterable<FlowchartDecisionNode> taskCombinationDecision = [];
  bool continueTaskDependent = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _predefinedTaskQuestion = TextEditingController();
  final _predefinedTaskDecision1 = TextEditingController();
  final _predefinedTaskDecision2 = TextEditingController();
  String? comb_chosenPredefinedTaskId;
  String? comb_chosenPredefinedTaskId2;
  List<Widget> decisionWidgets = [];
  Map<String, TextEditingController> alreadyDefinedDecisionControllers = {};
  Map<int, String> savingKeys = {};
  Map<String, String?> alreadyDefinedDecisionDropdownValues = {};
  int decisionCounter = 3;
  Map<int, TextEditingController> decisionControllers = {};
  Map<int, String?> decisionDropdownValues = {};

  List<Widget> generateDecisionWidgets({required FlowchartNode task}) {
    List<Widget> widgets = [];
    int decisionNumber = 1;
    int index = 0;
    savingKeys.clear();
    alreadyDefinedDecisionControllers.clear();
    alreadyDefinedDecisionDropdownValues.clear();
    var decisionNodes = task.decisionNodes ?? [];

    for (int i = 0; i < decisionNodes.length; i++) {
      String key = 'part_${DateTime.now().microsecond}$i';
      savingKeys.putIfAbsent(index, () => key);
      if (!alreadyDefinedDecisionControllers.containsKey(key)) {
        TextEditingController controller =
            TextEditingController(text: decisionNodes[i].answer);
        controller.addListener(() {
          setState(() {
            decisionNodes[i].answer = controller.text;
          });
        });
        alreadyDefinedDecisionControllers[key] = controller;
      }

      alreadyDefinedDecisionDropdownValues.putIfAbsent(
        key,
        () => decisionNodes[i].followupNodeId,
      );

      // Create the decision widget
      Widget decisionWidget = Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: alreadyDefinedDecisionControllers[key],
                decoration: InputDecoration(
                  labelText: 'החלטה $decisionNumber',
                  border: const OutlineInputBorder(),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue, width: 2.0),
                  ),
                  prefixIcon: const Icon(Icons.question_mark),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'שדה זה הוא חובה';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: alreadyDefinedDecisionDropdownValues[key],
                onChanged: (String? newValue) {
                  setState(() {
                    alreadyDefinedDecisionDropdownValues[key] = newValue;
                  });
                },
                items: widget.predefinedTasks.map((pt) {
                  return DropdownMenuItem<String>(
                    value: pt.id,
                    child: Text(pt.label),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );

      widgets.add(decisionWidget);
      decisionNumber++;
      index++;
    }

    return widgets;
  }

  Future<dynamic> _showSelectPredefinedTasksDialog({
    List<String>? preSelectedTasks,
    List<String>? hideTasks,
    String? title,
    FlowchartNode? task,
  }) async {
    final deviceSize = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final bottomPadding = kIsWeb
        ? 0
        : Platform.isIOS
            ? 0
            : padding.bottom;
    final deviceHeight = deviceSize.height - bottomPadding;
    List<String> selectedPredefinedTasks = preSelectedTasks ?? [];
    final TextEditingController taskCombinationQuestionName =
        TextEditingController();
    if (title == 'בחר את משימות ההמשך הישירות אחרי המשימה הנוכחית') {
      if (task!.isFollowedByDecision == true) {
        taskCombinationDecision = task.decisionNodes!;
        taskCombinationQuestionName.text = task.decisionQuestion!;
        setState(() {
          continueTaskDependent = true;
        });
      }
    }

    final result = await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                title ?? 'בחר את המשימות שברצונך להוסיף לתהליך האוטומטי',
              ),
              content: title !=
                      'בחר את משימות ההמשך הישירות אחרי המשימה הנוכחית'
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Theme(
                          data: Theme.of(context).copyWith(
                            scrollbarTheme: ScrollbarThemeData(
                              thumbVisibility: MaterialStateProperty.all(true),
                              thumbColor:
                                  MaterialStateProperty.all(Colors.grey),
                            ),
                          ),
                          child: MultiSelectDialogField(
                            initialValue: selectedPredefinedTasks,
                            items: widget.predefinedTasks
                                .where((e) =>
                                    (hideTasks == null ||
                                        !hideTasks.contains(e.id)) &&
                                    e.id != task?.id)
                                .map((task) =>
                                    MultiSelectItem(task.id, task.label))
                                .toList(),
                            title: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("בחירה"),
                                SizedBox(width: 5),
                                Tooltip(
                                  message: 'בחר משימות תלויות למשימה הנוכחית',
                                  child: const Icon(
                                    Icons.help_outline,
                                    size: 20,
                                    textDirection: TextDirection.ltr,
                                  ),
                                ),
                              ],
                            ),
                            dialogHeight: deviceHeight * 0.6,
                            dialogWidth: deviceSize.width * 0.5,
                            searchable: true,
                            searchHint: 'חיפוש',
                            confirmText: const Text('אישור'),
                            cancelText: const Text('ביטול'),
                            buttonText: const Text('בחר משימות'),
                            onConfirm: (values) {
                              selectedPredefinedTasks =
                                  List<String>.from(values);
                            },
                          ),
                        ),
                      ],
                    )
                  : widget.nodes.any((e) =>
                          e.id == task?.id && e.isFollowedByDecision == false)
                      ? !continueTaskDependent
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Theme(
                                  data: Theme.of(context).copyWith(
                                    scrollbarTheme: ScrollbarThemeData(
                                      thumbVisibility:
                                          MaterialStateProperty.all(true),
                                      thumbColor: MaterialStateProperty.all(
                                          Colors.grey),
                                    ),
                                  ),
                                  child: MultiSelectDialogField(
                                    initialValue: selectedPredefinedTasks,
                                    items: widget.predefinedTasks
                                        .where((e) =>
                                            (hideTasks == null ||
                                                !hideTasks.contains(e.id)) &&
                                            e.id != task?.id)
                                        .map((tasks) => MultiSelectItem(
                                              tasks.id,
                                              tasks.label,
                                            ))
                                        .toList(),
                                    title: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text("בחירה"),
                                        SizedBox(width: 5),
                                        Tooltip(
                                          message:
                                              'בחר משימות תלויות למשימה הנוכחית',
                                          child: Icon(
                                            Icons.help_outline,
                                            size: 20,
                                            textDirection: TextDirection.ltr,
                                          ),
                                        ),
                                      ],
                                    ),
                                    dialogHeight: deviceHeight * 0.6,
                                    dialogWidth: deviceSize.width * 0.5,
                                    searchable: true,
                                    searchHint: 'חיפוש',
                                    confirmText: const Text('אישור'),
                                    cancelText: const Text('ביטול'),
                                    buttonText: const Text('בחר משימות'),
                                    onConfirm: (values) {
                                      selectedPredefinedTasks =
                                          List<String>.from(values);
                                    },
                                  ),
                                ),
                                // const SizedBox(height: 10),
                                // SizedBox(
                                //   width: 300,
                                //   child: CheckboxListTile(
                                //     title: const Text(
                                //       'המשך משימה זו תלוי בהחלטה',
                                //       textDirection: TextDirection.rtl,
                                //     ),
                                //     value: continueTaskDependent,
                                //     onChanged: (value) {
                                //       setState(() {
                                //         continueTaskDependent = value!;
                                //       });
                                //     },
                                //   ),
                                // ),
                              ],
                            )
                          : Form(
                              key: _formKey,
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  scrollbarTheme: ScrollbarThemeData(
                                    thumbVisibility:
                                        MaterialStateProperty.all(true),
                                    thumbColor:
                                        MaterialStateProperty.all(Colors.grey),
                                    thickness: MaterialStateProperty.all(6.0),
                                  ),
                                ),
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 300,
                                        child: CheckboxListTile(
                                          title: const Text(
                                            'המשך משימה זו תלוי בהחלטה',
                                            textDirection: TextDirection.rtl,
                                          ),
                                          value: continueTaskDependent,
                                          onChanged: (value) {
                                            setState(() {
                                              continueTaskDependent = value!;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: TextFormField(
                                          controller: _predefinedTaskQuestion,
                                          decoration: const InputDecoration(
                                            labelText: 'שאלה',
                                            border: OutlineInputBorder(),
                                            focusedBorder: OutlineInputBorder(
                                              borderSide: BorderSide(
                                                  color: Colors.blue,
                                                  width: 2.0),
                                            ),
                                            prefixIcon:
                                                Icon(Icons.question_mark),
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'שדה זה הוא חובה';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 1,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: TextField(
                                                controller:
                                                    _predefinedTaskDecision1,
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: 'החלטה 1 ',
                                                  border: OutlineInputBorder(),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                        color: Colors.blue,
                                                        width: 2.0),
                                                  ),
                                                  prefixIcon: Icon(
                                                      Icons.question_answer),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          Expanded(
                                            child:
                                                DropdownButtonFormField<String>(
                                              value:
                                                  comb_chosenPredefinedTaskId,
                                              hint:
                                                  const Text("בחר משימת המשך"),
                                              onChanged:
                                                  (String? newValue) async {
                                                setState(() {
                                                  comb_chosenPredefinedTaskId =
                                                      newValue;
                                                });
                                              },
                                              items: widget.predefinedTasks
                                                  .where(
                                                      (pt) => pt.id != task?.id)
                                                  .map((pt) =>
                                                      DropdownMenuItem<String>(
                                                        value: pt.id,
                                                        child: Text(pt.label),
                                                      ))
                                                  .toList(),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 1,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: TextField(
                                                controller:
                                                    _predefinedTaskDecision2,
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: 'החלטה 2 ',
                                                  border: OutlineInputBorder(),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                        color: Colors.blue,
                                                        width: 2.0),
                                                  ),
                                                  prefixIcon: Icon(
                                                      Icons.question_answer),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          Expanded(
                                            child:
                                                DropdownButtonFormField<String>(
                                              value:
                                                  comb_chosenPredefinedTaskId2,
                                              hint:
                                                  const Text("בחר משימת המשך"),
                                              onChanged:
                                                  (String? newValue) async {
                                                setState(() {
                                                  comb_chosenPredefinedTaskId2 =
                                                      newValue;
                                                });
                                              },
                                              items: widget.predefinedTasks
                                                  .where(
                                                      (pt) => pt.id != task?.id)
                                                  .map((pt) =>
                                                      DropdownMenuItem<String>(
                                                        value: pt.id,
                                                        child: Text(pt.label),
                                                      ))
                                                  .toList(),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        children: decisionWidgets,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                      : continueTaskDependent
                          ? Form(
                              key: _formKey,
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  scrollbarTheme: ScrollbarThemeData(
                                    thumbVisibility:
                                        MaterialStateProperty.all(true),
                                    thumbColor:
                                        MaterialStateProperty.all(Colors.grey),
                                    thickness: MaterialStateProperty.all(6.0),
                                  ),
                                ),
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 300,
                                        child: CheckboxListTile(
                                          title: const Text(
                                            'המשך משימה זו תלוי בהחלטה',
                                            textDirection: TextDirection.rtl,
                                          ),
                                          value: continueTaskDependent,
                                          onChanged: (value) {
                                            setState(() {
                                              continueTaskDependent = value!;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: TextFormField(
                                          controller:
                                              taskCombinationQuestionName,
                                          decoration: const InputDecoration(
                                            labelText: 'שאלה',
                                            border: OutlineInputBorder(),
                                            focusedBorder: OutlineInputBorder(
                                              borderSide: BorderSide(
                                                  color: Colors.blue,
                                                  width: 2.0),
                                            ),
                                            prefixIcon:
                                                Icon(Icons.question_mark),
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'שדה זה הוא חובה';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Column(
                                        children: generateDecisionWidgets(
                                          task: task!,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Theme(
                                  data: Theme.of(context).copyWith(
                                    scrollbarTheme: ScrollbarThemeData(
                                      thumbVisibility:
                                          MaterialStateProperty.all(true),
                                      thumbColor: MaterialStateProperty.all(
                                          Colors.grey),
                                    ),
                                  ),
                                  child: MultiSelectDialogField(
                                    initialValue: selectedPredefinedTasks,
                                    items: widget.predefinedTasks
                                        .where((e) =>
                                            (hideTasks == null ||
                                                !hideTasks.contains(e.id)) &&
                                            e.id != task?.id)
                                        .map((tasks) => MultiSelectItem(
                                            tasks.id, tasks.label))
                                        .toList(),
                                    title: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text("בחירה"),
                                        SizedBox(width: 5),
                                        Tooltip(
                                          message:
                                              'בחר משימות תלויות למשימה הנוכחית',
                                          child: Icon(
                                            Icons.help_outline,
                                            size: 20,
                                            textDirection: TextDirection.ltr,
                                          ),
                                        ),
                                      ],
                                    ),
                                    dialogHeight: deviceHeight * 0.6,
                                    dialogWidth: deviceSize.width * 0.5,
                                    searchable: true,
                                    searchHint: 'חיפוש',
                                    confirmText: const Text('אישור'),
                                    cancelText: const Text('ביטול'),
                                    buttonText: const Text('בחר משימות'),
                                    onConfirm: (values) {
                                      selectedPredefinedTasks =
                                          List<String>.from(values);
                                    },
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: 300,
                                  child: CheckboxListTile(
                                    title: const Text(
                                      'המשך משימה זו תלוי בהחלטה',
                                      textDirection: TextDirection.rtl,
                                    ),
                                    value: continueTaskDependent,
                                    onChanged: (value) {
                                      setState(() {
                                        continueTaskDependent = value!;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
              actions: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    title == 'בחר את משימות ההמשך הישירות אחרי המשימה הנוכחית'
                        ? widget.nodes.any((e) =>
                                e.id == task!.id &&
                                e.isFollowedByDecision == false)
                            ? continueTaskDependent
                                ? Row(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            int currentDecisionIndex =
                                                decisionCounter;

                                            TextEditingController
                                                newController =
                                                TextEditingController();
                                            decisionControllers[
                                                    currentDecisionIndex] =
                                                newController;

                                            String? newValue;
                                            decisionDropdownValues[
                                                    currentDecisionIndex] =
                                                newValue;

                                            decisionWidgets.add(
                                              Row(
                                                children: [
                                                  Expanded(
                                                    flex: 1,
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8.0),
                                                      child: TextField(
                                                        controller:
                                                            newController,
                                                        decoration:
                                                            InputDecoration(
                                                          labelText:
                                                              'החלטה $decisionCounter',
                                                          border:
                                                              const OutlineInputBorder(),
                                                          focusedBorder:
                                                              const OutlineInputBorder(
                                                            borderSide:
                                                                BorderSide(
                                                                    color: Colors
                                                                        .blue,
                                                                    width: 2.0),
                                                          ),
                                                          prefixIcon:
                                                              const Icon(Icons
                                                                  .question_answer),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 20),
                                                  Expanded(
                                                    child:
                                                        DropdownButtonFormField<
                                                            String>(
                                                      value: decisionDropdownValues[
                                                          currentDecisionIndex],
                                                      hint: const Text(
                                                          "בחר משימת המשך"),
                                                      onChanged: (String?
                                                          newValue) async {
                                                        setState(() {
                                                          decisionDropdownValues[
                                                                  currentDecisionIndex] =
                                                              newValue;
                                                        });
                                                      },
                                                      items: widget
                                                          .predefinedTasks
                                                          .where((pt) =>
                                                              pt.id != task!.id)
                                                          .map((pt) =>
                                                              DropdownMenuItem<
                                                                  String>(
                                                                value: pt.id,
                                                                child: Text(
                                                                    pt.label),
                                                              ))
                                                          .toList(),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );

                                            decisionCounter++;
                                          });
                                        },
                                        icon: const Icon(Icons.add),
                                        label: const Text('החלטה נוספת'),
                                      ),
                                      const SizedBox(width: 10),
                                      decisionWidgets.isNotEmpty
                                          ? ElevatedButton.icon(
                                              onPressed: () {
                                                setState(() {
                                                  if (decisionWidgets
                                                      .isNotEmpty) {
                                                    if (decisionWidgets
                                                            .length ==
                                                        1) {
                                                      decisionWidgets.clear();
                                                      decisionControllers
                                                          .clear();
                                                      decisionDropdownValues
                                                          .clear();
                                                      decisionCounter = 3;
                                                    } else {
                                                      decisionWidgets
                                                          .removeLast();
                                                      decisionControllers
                                                          .remove(
                                                              decisionCounter);
                                                      decisionDropdownValues
                                                          .remove(
                                                              decisionCounter);
                                                      decisionCounter--;
                                                    }
                                                  }
                                                });
                                              },
                                              icon: const Icon(Icons.remove),
                                              label: const Text(
                                                  'הסר החלטה האחרונה'),
                                            )
                                          : const SizedBox(),
                                    ],
                                  )
                                : const SizedBox()
                            : const SizedBox()
                        : const SizedBox(),
                    ElevatedButton(
                      onPressed: () async {
                        if (title ==
                            'בחר את משימות ההמשך הישירות אחרי המשימה הנוכחית') {
                          bool allFieldsFilled;
                          bool alreadyDefinedAllFieldsFilled;
                          if (decisionControllers.isEmpty) {
                            allFieldsFilled = true;
                          } else {
                            allFieldsFilled = decisionControllers.values.every(
                                    (controller) =>
                                        controller.text.isNotEmpty) &&
                                decisionDropdownValues.values
                                    .every((value) => value != null);
                          }
                          if (alreadyDefinedDecisionControllers.isEmpty) {
                            alreadyDefinedAllFieldsFilled = true;
                          } else {
                            alreadyDefinedAllFieldsFilled =
                                alreadyDefinedDecisionControllers.values.every(
                                        (controller) =>
                                            controller.text.isNotEmpty) &&
                                    alreadyDefinedDecisionDropdownValues.values
                                        .every((value) => value != null);
                          }

                          if (continueTaskDependent == true) {
                            if ((_formKey.currentState!.validate() &&
                                comb_chosenPredefinedTaskId2 != null &&
                                comb_chosenPredefinedTaskId != null &&
                                allFieldsFilled != false)) {
                              // selectedPredefinedTasks.clear();

                              final dataToReturn = {
                                'selectedPredefinedTasks':
                                    selectedPredefinedTasks,
                                'decisionControllers': decisionControllers,
                                'decisionDropdownValues':
                                    decisionDropdownValues,
                                'decisionCounter': decisionCounter,
                                'question': _predefinedTaskQuestion.text,
                                'predefinedTaskDecision1':
                                    _predefinedTaskDecision1.text,
                                'predefinedTaskDecision2':
                                    _predefinedTaskDecision2.text,
                                'comb_chosenPredefinedTaskId2':
                                    comb_chosenPredefinedTaskId2,
                                'comb_chosenPredefinedTaskId':
                                    comb_chosenPredefinedTaskId,
                                'continueTaskDependent': continueTaskDependent,
                              };

                              Navigator.of(context).pop(dataToReturn);
                              setState(() {
                                decisionWidgets.clear();
                                continueTaskDependent = false;
                                decisionCounter = 3;
                                _predefinedTaskQuestion.clear();
                                _predefinedTaskDecision1.clear();
                                _predefinedTaskDecision2.clear();
                                comb_chosenPredefinedTaskId = null;
                                comb_chosenPredefinedTaskId2 = null;
                              });
                            } else if (alreadyDefinedAllFieldsFilled != false) {
                              final dataToReturn = {
                                'selectedPredefinedTasks':
                                    selectedPredefinedTasks,
                                'alreadyDefinedDecisionDropdownValues':
                                    alreadyDefinedDecisionDropdownValues,
                                'alreadyDefinedDecisionControllers':
                                    alreadyDefinedDecisionControllers,
                                'taskCombinationQuestionName':
                                    taskCombinationQuestionName.text,
                                'continueTaskDependent': continueTaskDependent,
                              };

                              Navigator.of(context).pop(dataToReturn);
                            } else {
                              showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: const Text('שגיאה'),
                                    content: const Text(
                                        'יש למלא את כל השדות לפני המשך'),
                                    actions: <Widget>[
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text('אישור'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            }
                          } else {
                            final dataToReturn = {
                              'selectedPredefinedTasks':
                                  selectedPredefinedTasks,
                            };

                            Navigator.of(context).pop(dataToReturn);
                          }
                        } else {
                          final dataToReturn = {
                            'selectedPredefinedTasks': selectedPredefinedTasks,
                          };

                          Navigator.of(context).pop(dataToReturn);
                        }
                      },
                      child: const Text('עדכון'),
                    ),
                  ],
                )
              ],
            );
          },
        );
      },
    ).then((result) {
      if (result == null) {
        setState(() {
          decisionWidgets.clear();
          continueTaskDependent = false;
          decisionCounter = 3;
          _predefinedTaskQuestion.clear();
          _predefinedTaskDecision1.clear();
          _predefinedTaskDecision2.clear();
          comb_chosenPredefinedTaskId = null;
          comb_chosenPredefinedTaskId2 = null;
        });
      }
      return result;
    });

    return result ?? {};
  }

  Future<void> _removeDecisionLink(
    FlowchartNode currentTask,
    String nextID,
    String name,
  ) async {
    setState(() {
      _isLoadingChart = true;
    });
    try {
      await widget.onRemoveDecisionLink(id: currentTask.id, name: name);
      //   await deletePredefinedTasksFromCombinationSingleDecision(
      //     combID: combID,
      //     name: name,
      //   );
      //   await dbProvider.deleteTaskCombination_SingleDecision(
      //     combID: combID,
      //     name: name,
      //   );
      _combDependencies[currentTask.id]!['FollowUps']?.remove(nextID);
      currentTask.decisionNodes!.removeWhere(
        (e) => e.followupNodeId == nextID,
      );
      _flowChart
          .singleWhere((e) => e.id == "${currentTask.id}__FOLLOWUP")
          .next
          .removeWhere((next) => next.outcome == nextID.toString());
      _buildGraph();
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      setState(() {
        _isLoadingChart = false;
      });
    }
  }

  Future<void> _removeFollowupLink(String taskId, String followupId) async {
    setState(() {
      _isLoadingChart = true;
    });
    try {
      await widget.onRemoveFollowUpLink(id: taskId, followupId: followupId);
      // await deletePredefinedTasksFromCombinationFollowUp(
      //   combID: combID,
      //   nextID: nextID,
      // );
      // await dbProvider.deleteTaskCombination_FollowUpsById(
      //   combID: combID,
      //   nextID: nextID,
      // );
      _combDependencies[taskId]!['FollowUps']?.remove(followupId);
      _flowChart
          .singleWhere((e) => e.id == taskId.toString())
          .next
          .removeWhere((next) => next.outcome == followupId.toString());
      _buildGraph();
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      setState(() {
        _isLoadingChart = false;
      });
    }
  }

  Future<void> _removeDependOnLink(String taskId, String dependsOnID) async {
    setState(() {
      _isLoadingChart = true;
    });
    try {
      await widget.onRemoveDependOnLink(id: taskId, dependsOnId: dependsOnID);
      // await deletePredefinedTasksFromCombinationDependsOn(
      //   combID: combID,
      //   dependsOnID: dependsOnID,
      // );
      // await dbProvider.deleteTaskCombination_DependsOnById(
      //   combID: combID,
      //   dependsOnID: dependsOnID,
      // );
      _combDependencies[taskId]!['DependsOn']?.remove(dependsOnID);
      _flowChart
          .singleWhere((e) => e.id == dependsOnID.toString())
          .next
          .removeWhere((next) => next.outcome == taskId.toString());
      _buildGraph();
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      setState(() {
        _isLoadingChart = false;
      });
    }
  }

  List<DataRow> _getRelationsDatarows({
    required FlowchartNode currentTask,
    required bool isFollowups,
    required bool isFollowedByDecision,
    required Function onUpdating,
    required Function onDoneUpdating,
    bool allowDeleted = true,
  }) {
    var res = _combDependencies[currentTask.id]![
            isFollowups ? 'FollowUps' : 'DependsOn']!
        .map(
      (tID) {
        var task = widget.nodes.singleWhere((e) => e.id == tID);
        // var predefinedTask = _predefinedTasksData
        //     .singleWhere((e) => e.ID == combination.PredefinedTasksID);
        return DataRow(cells: [
          if (isFollowedByDecision)
            DataCell(
              Text(
                currentTask.decisionNodes!
                    .singleWhere((e) => e.followupNodeId == tID)
                    .answer,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          DataCell(
            Text(
              task.label,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          DataCell(
            !allowDeleted
                ? Container()
                : Directionality(
                    textDirection: TextDirection.ltr,
                    child: ElevatedButton.icon(
                      icon: const Icon(
                        Icons.delete_rounded,
                        color: Colors.red,
                      ),
                      label: Text(
                        isFollowedByDecision ? 'מחיקת החלטה' : 'מחיקת תלות',
                        textAlign: TextAlign.right,
                      ),
                      onPressed: () async {
                        onUpdating.call();
                        if (isFollowups) {
                          if (isFollowedByDecision) {
                            await _removeDecisionLink(
                              currentTask,
                              tID,
                              currentTask.decisionNodes!
                                  .singleWhere((e) => e.followupNodeId == tID)
                                  .answer,
                            );
                          } else {
                            await _removeFollowupLink(currentTask.id, tID);
                          }
                        } else {
                          await _removeDependOnLink(currentTask.id, tID);
                        }
                        onDoneUpdating.call();
                      },
                      style: ElevatedButton.styleFrom(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(7.0),
                          ),
                          side: BorderSide(
                            color: Colors.red,
                            width: 2,
                          ),
                        ),
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
          ),
        ]);
      },
    ).toList();

    // if (!isFollowups) {
    //   // Add also tasks that this task is a followup to
    //   res.addAll(_combDependencies.keys
    //       .where((k) =>
    //           _combDependencies[k]![isFollowups ? 'DependsOn' : 'FollowUps']!
    //               .contains(currentTask.id))
    //       .map(
    //     (comb) {
    //       var task = widget.nodes.singleWhere((e) => e.id == comb);
    //       // var predefinedTask = _predefinedTasksData
    //       //     .singleWhere((e) => e.ID == combination.PredefinedTasksID);
    //       return DataRow(cells: [
    //         DataCell(
    //           Text(
    //             task.label,
    //             style: const TextStyle(fontSize: 16),
    //           ),
    //         ),
    //         DataCell(
    //           Directionality(
    //             textDirection: TextDirection.ltr,
    //             child: ElevatedButton.icon(
    //               icon: const Icon(Icons.delete_rounded),
    //               label: const Text('מחיקת תלות'),
    //               onPressed: () async {
    //                 onUpdating.call();
    //                 if (isFollowups) {
    //                   await _removeDependOnLink(comb, task.id);
    //                 } else {
    //                   await _removeFollowupLink(comb, task.id);
    //                 }
    //                 onDoneUpdating.call();
    //               },
    //               style: ElevatedButton.styleFrom(
    //                 shape: const RoundedRectangleBorder(
    //                   borderRadius: BorderRadius.all(
    //                     Radius.circular(7.0),
    //                   ),
    //                   side: BorderSide(
    //                     color: Colors.red,
    //                     width: 2,
    //                   ),
    //                 ),
    //                 foregroundColor: Colors.red,
    //               ),
    //             ),
    //           ),
    //         ),
    //       ]);
    //     },
    //   ).toList());
    // }

    if ((!isFollowedByDecision && isFollowups) || !isFollowups) {
      // Add also tasks that depend on this task (they dont appear as "Followup" relation)
      res.addAll(_combDependencies.keys
          .where((k) =>
              _combDependencies[k]![isFollowups ? 'DependsOn' : 'FollowUps']!
                  .contains(currentTask.id))
          .map(
        (taskID) {
          var task = widget.nodes.singleWhere((e) => e.id == taskID);
          // var predefinedTask = _predefinedTasksData
          //     .singleWhere((e) => e.ID == combination.PredefinedTasksID);
          return DataRow(cells: [
            DataCell(
              Text(
                task.label,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            DataCell(
              Directionality(
                textDirection: TextDirection.ltr,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.delete_rounded, color: Colors.red),
                  label: const Text('מחיקת תלות'),
                  onPressed: () async {
                    onUpdating.call();
                    if (isFollowups) {
                      await _removeDependOnLink(taskID, task.id);
                    } else {
                      await _removeFollowupLink(taskID, currentTask.id);
                    }
                    onDoneUpdating.call();
                  },
                  style: ElevatedButton.styleFrom(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(7.0),
                      ),
                      side: BorderSide(
                        color: Colors.red,
                        width: 2,
                      ),
                    ),
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
            ),
          ]);
        },
      ).toList());
    }

    if (res.isEmpty) {
      return [
        DataRow(cells: [
          const DataCell(
            Text(
              "אין משימות",
              style: TextStyle(
                fontSize: 16,
                color: Color.fromARGB(255, 116, 116, 116),
              ),
            ),
          ),
          DataCell(Container()),
        ])
      ];
    }

    return res;
  }

  Future<void> _convertFollowupToDependent(
    FlowchartNode editedTask,
  ) async {
    Map<int, TextEditingController> answersControllers = {
      1: TextEditingController(),
      2: TextEditingController(),
    };
    Map<int, String?> answerFollowupID = {
      1: null,
      2: null,
    };
    Tuple2<Map, Map>? res = await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (_, setDecisionsState) {
            List<int> sortedKeys = answersControllers.keys.toList()..sort();
            int i = 0;
            return AlertDialog(
              title: const Center(
                child: Text('בחירת שאלה ואפשרויות'),
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Form(
                      key: _formKey,
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          scrollbarTheme: ScrollbarThemeData(
                            thumbVisibility: MaterialStateProperty.all(true),
                            thumbColor: MaterialStateProperty.all(Colors.grey),
                            thickness: MaterialStateProperty.all(6.0),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextFormField(
                                controller: _predefinedTaskQuestion,
                                decoration: const InputDecoration(
                                  labelText: 'שאלה',
                                  border: OutlineInputBorder(),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Colors.blue, width: 2.0),
                                  ),
                                  prefixIcon: Icon(Icons.question_mark),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'אנא הזן שאלה';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...sortedKeys.map(
                              (k) {
                                i++;
                                return Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: TextFormField(
                                          controller: answersControllers[k],
                                          decoration: InputDecoration(
                                            labelText: 'החלטה $i',
                                            border: const OutlineInputBorder(),
                                            focusedBorder:
                                                const OutlineInputBorder(
                                              borderSide: BorderSide(
                                                  color: Colors.blue,
                                                  width: 2.0),
                                            ),
                                            prefixIcon: const Icon(
                                                Icons.question_answer),
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'אנא הזן החלטה';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: answerFollowupID[k],
                                        hint: const Text("בחר משימת המשך"),
                                        onChanged: (String? newValue) async {
                                          setDecisionsState(() {
                                            answerFollowupID[k] = newValue;
                                          });
                                        },
                                        items: widget.predefinedTasks
                                            .map((pt) =>
                                                DropdownMenuItem<String>(
                                                  value: pt.id,
                                                  child: Text(pt.label),
                                                ))
                                            .toList(),
                                        validator: (value) {
                                          if (value == null) {
                                            return 'אנא בחר אפשרות';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    if (sortedKeys.length > 2)
                                      const SizedBox(width: 20),
                                    if (sortedKeys.length > 2)
                                      InkWell(
                                        child: const Icon(
                                          Icons.delete_rounded,
                                        ),
                                        onTap: () {
                                          setDecisionsState(() {
                                            answerFollowupID.remove(k);
                                            answersControllers.remove(k);
                                          });
                                        },
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_rounded),
                        label: const Text(
                          'אפשרות נוספת',
                        ),
                        onPressed: () {
                          int t = DateTime.now().millisecondsSinceEpoch;
                          setDecisionsState(() {
                            answersControllers[t] = TextEditingController();
                            answerFollowupID[t] = null;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(7.0)),
                            side: BorderSide(
                              color: Colors.blue,
                              width: 2,
                            ),
                          ),
                          foregroundColor: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('ביטול'),
                  onPressed: () {
                    _predefinedTaskQuestion.clear();
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('אישור'),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      Navigator.of(context).pop(Tuple2<Map, Map>(
                        answersControllers,
                        answerFollowupID,
                      ));
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );

    if (res != null) {
      setState(() {
        _isLoadingChart = true;
      });
      try {
        debugPrint(res.item2.toString());
        Map answersControllers = res.item1;
        Map answerFollowupID = res.item2;
        // await updatePredefinedTasksCombination(
        //   combID: combID,
        //   isFollowedByDecision: true,
        //   decisionQuestion: _predefinedTaskQuestion.text,
        // );
        await widget.onConvertFollowupToDecision(
          taskId: editedTask.id,
          question: _predefinedTaskQuestion.text,
          answers: answersControllers.map(
            (key, controller) =>
                MapEntry(key, (controller as TextEditingController).text),
          ),
          followupIDs: answerFollowupID,
        );

        _nodes["${editedTask.id}__FOLLOWUP"] = FlowStep(
          text: _predefinedTaskQuestion.text,
          type: FlowStepType.decision,
          isCompleted: false,
          isSkipped: false,
          canProgress: false,
        );
        _flowChart.singleWhere((e) => e.id == editedTask.id).next.removeWhere(
              (e) => _combDependencies[editedTask.id]!['FollowUps']!.contains(
                e.outcome,
              ),
            );

        _flowChart.add(
          NodeInput(
            id: "${editedTask.id}__FOLLOWUP",
            next: [],
            size: const NodeSize(
              width: 100,
              height: 100,
            ),
          ),
        );
        _flowChart.singleWhere((e) => e.id == editedTask.id).next.add(
              EdgeInput(
                outcome: "${editedTask.id}__FOLLOWUP",
              ),
            );
        _combDependencies[editedTask.id]!['FollowUps']!.clear();

        // var newFollowups = answersControllers.keys
        //     .map(
        //       (k) => answerFollowupID[k] as String,
        //     )
        //     .toList();
        // var resMap = await addPredefinedTasksCombination(
        //   caseTypeId: comb_chosenCaseTypeId!,
        //   departmentId: comb_chosenDepartmentId!,
        //   predefinedTasksIDs: newFollowups,
        // );
        // for (String id in newFollowups) {
        //   String newCombID =
        //     resMap['mapping'][id];
        //   var newComb = TaskCombination_X_PredefinedTasks(
        //     ID: newCombID,
        //     CombinationID: comb_chosenCombinationId!,
        //     PredefinedTasksID: id,
        //     IsFollowedByDecision: false,
        //     DecisionQuestion: null,
        //   );
        //   await dbProvider.addTaskCombination_X_PredefinedTasks(newComb);
        //   _taskCombination_X_PredefinedTasks.add(newComb);
        //   comb_currentPredefinedTasks.add(newComb);

        //   var predefinedTask = _predefinedTasksData.singleWhere(
        //     (e) => e.ID == newComb.PredefinedTasksID,
        //   );
        //   _nodes[newComb.ID.toString()] = FlowStep(
        //     text: predefinedTask.Name,
        //     type: FlowStepType.process,
        //     isCompleted: false,
        //     isSkipped: false,
        //     canProgress: false,
        //   );
        //   _flowChart.add(
        //     NodeInput(id: newComb.ID.toString(), next: []),
        //   );

        //   _flowChart.singleWhere((e) => e.id == "${editedTask.id}__FOLLOWUP").next.add(
        //         EdgeInput(
        //           outcome: newCombID.toString(),
        //         ),
        //       );
        //   _combDependencies[editedTask.id]!['FollowUps']!.add(newCombID);
        //   _combDependencies[newCombID] = {
        //     'DependsOn': [],
        //     'FollowUps': [],
        //   };
        // }

        // var newDecisions = answersControllers.keys
        //     .map(
        //       (k) => FlowchartDecisionNode(
        //         nodeId: editedTask.id,
        //         answer: (answersControllers[k] as TextEditingController).text,
        //         followupNodeId:
        //             resMap['mapping'][answerFollowupID[k]],
        //       ),
        //     )
        //     .toList();
        // await updatePredefinedTasksCombinationDecisions(
        //   combID: editedTask.id,
        //   followUpsIDs: newDecisions,
        // );
        // await dbProvider.updateTaskCombination_X_PredefinedTasks(
        //   id: editedTask.id,
        //   newVal: TaskCombination_X_PredefinedTasks(
        //     ID: editedTask.id,
        //     CombinationID: editedComb.CombinationID,
        //     PredefinedTasksID: editedComb.PredefinedTasksID,
        //     IsFollowedByDecision: true,
        //   ),
        // );
        // editedTask.decisionNodes = newDecisions;
        // for (var newDecision in newDecisions) {
        //   await dbProvider.addTaskCombination_Decisions(
        //     newDecision,
        //   );
        // }

        editedTask.isFollowedByDecision = true;
        editedTask.decisionQuestion = _predefinedTaskQuestion.text;
        _buildGraph();
      } catch (e) {
        debugPrint(e.toString());
      } finally {
        _predefinedTaskQuestion.clear();
        setState(() {
          _isLoadingChart = false;
        });
      }
    }
  }

  Future<void> _convertFollowupToIndependent(
    String editedTaskId,
  ) async {
    setState(() {
      _isLoadingChart = true;
    });
    try {
      var editedTask = widget.nodes.singleWhere((t) => t.id == editedTaskId);
      // await updatePredefinedTasksCombination(
      //   combID: combID,
      //   isFollowedByDecision: false,
      //   decisionQuestion: null,
      // );
      await widget.onRemoveDecisionNode(taskId: editedTask.id);

      _nodes.remove("${editedTask.id}__FOLLOWUP");
      _nodes["${editedTask.id}__FOLLOWUP"] = FlowStep(
        text: _predefinedTaskQuestion.text,
        type: FlowStepType.decision,
        isCompleted: false,
        isSkipped: false,
        canProgress: false,
      );

      // Replace link to go directly to all decisions
      _flowChart
          .singleWhere((e) => e.id == editedTask.id)
          .next
          .removeWhere((n) => n.outcome == "${editedTask.id}__FOLLOWUP");
      _flowChart.singleWhere((e) => e.id == editedTask.id).next.addAll(
            _flowChart
                .singleWhere((e) => e.id == "${editedTask.id}__FOLLOWUP")
                .next,
          );
      _flowChart.removeWhere((e) => e.id == "${editedTask.id}__FOLLOWUP");

      // // Add each decision as direct followup
      // await updatePredefinedTasksCombinationFollowUps(
      //   combID: combID,
      //   followUpsIDs: _combDependencies[combID]!['FollowUps']!,
      // );

      // await dbProvider.updateTaskCombination_X_PredefinedTasks(
      //   id: combID,
      //   newVal: TaskCombination_X_PredefinedTasks(
      //     ID: combID,
      //     CombinationID: editedTask.CombinationID,
      //     PredefinedTasksID: editedTask.PredefinedTasksID,
      //     IsFollowedByDecision: false,
      //   ),
      // );

      editedTask.decisionNodes = null;
      editedTask.isFollowedByDecision = false;
      editedTask.decisionQuestion = null;
      _buildGraph();
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      _predefinedTaskQuestion.clear();
      setState(() {
        _isLoadingChart = false;
      });
    }
  }

  void _addDecisionSubTreeRecursively(
    String taskID,
    List<String> preceededByDecision,
  ) {
    var dependants = _combDependencies.keys
        .where((k) => _combDependencies[k]!['DependsOn']!.contains(taskID));
    preceededByDecision.addAll(dependants);
    for (var d in dependants) {
      _addDecisionSubTreeRecursively(d, preceededByDecision);
    }
  }

  Future<void> _onAddFromPredefinedTasks() async {
    var result = await _showSelectPredefinedTasksDialog();
    setState(() {
      _isLoadingChart = true;
    });
    try {
      if (result['selectedPredefinedTasks'] != null) {
        // List<TaskCombination_X_PredefinedTasks> newCombs = [];
        // var resMap = await addPredefinedTasksCombination(
        //   caseTypeId: comb_chosenCaseTypeId!,
        //   departmentId: comb_chosenDepartmentId!,
        //   predefinedTasksIDs: result['selectedPredefinedTasks'],
        //   isFollowedByDecision: false,
        //   decisionQuestion: null,
        // );

        List<FlowchartNode> newTasks = widget.predefinedTasks
            .where((e) => (result['selectedPredefinedTasks'] as List<String>)
                .contains(e.id))
            .toList();
        // Map<int, List<EdgeInput>> nextNodes = {};
        // for (int id in result['selectedPredefinedTasks']) {
        //   int combID = int.parse(
        //     resMap['mapping'][id.toString()],
        //   );
        //   PredefinedTask newTask =
        //       _predefinedTasksData.singleWhere((e) => e.ID == id);
        //   var newComb = TaskCombination_X_PredefinedTasks(
        //     ID: combID,
        //     CombinationID: comb_chosenCombinationId!,
        //     PredefinedTasksID: id,
        //     IsFollowedByDecision: false,
        //     DecisionQuestion: null,
        //   );
        //   await dbProvider.addTaskCombination_X_PredefinedTasks(newComb);
        //   _taskCombination_X_PredefinedTasks.add(newComb);
        //   newCombs.add(newComb);
        //   nextNodes[combID] = [];
        //   newTasks.add(newTask);
        // }

        CircularPathResponse circularPathResponse =
            await _checkNewChunkCircularDependencies(newTasks);

        if (!circularPathResponse.isFound) {
          // Recursively add DependsOn & FollowUps
          // await _insertFollowupsAndDependencies(
          //   result['selectedPredefinedTasks'] as List<int>,
          //   resMap,
          //   newCombs,
          //   nextNodes,
          // );
          await widget.onPredefinedTasksAdded(
            predefinedTaskIds: result['selectedPredefinedTasks'],
          );
        }

        // for (var p in newCombs) {
        //   var predefinedTask = _predefinedTasksData
        //       .singleWhere((e) => e.ID == p.PredefinedTasksID);
        //   _nodes[p.ID.toString()] = FlowStep(
        //     text: predefinedTask.Name,
        //     type: FlowStepType.process,
        //     isCompleted: false,
        //     isSkipped: false,
        //     canProgress: false,
        //   );
        //   _flowChart.add(
        //     NodeInput(
        //       id: p.ID.toString(),
        //       next: nextNodes[p.ID]!,
        //     ),
        //   );
        // }

        // setState(() {
        //   comb_currentPredefinedTasks.addAll(newCombs);
        // });

        if (circularPathResponse.isFound) {
          debugPrint("CIRCULAR PATH FOUND!:");
          _showCircularPathAlert(circularPathResponse);
        } else {
          _buildGraph();
        }
      }
    } finally {
      setState(() {
        _isLoadingChart = false;
      });
    }
  }

  Future<void> _onEditLinks(String taskID) async {
    final deviceSize = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final bottomPadding = Platform.isIOS ? 0 : padding.bottom;
    final deviceHeight = deviceSize.height - bottomPadding;
    bool isUpdatingDeps = false;
    bool isUpdatingFollowups = false;
    double tableSize = deviceSize.width * 0.75 - 20 - 20 - 30;
    var editedTask = widget.nodes.singleWhere((e) => e.id == taskID);

    final result = await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (_, setDialogState) {
            return AlertDialog(
              title: const Center(child: Text('עריכת תלויות')),
              content: SizedBox(
                height: deviceHeight * 0.8,
                width: deviceSize.width * 0.75,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      height: deviceHeight * 0.37,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "משימות שמשימה זו תלויה בהן:",
                                style: TextStyle(fontSize: 18),
                              ),
                              ElevatedButton(
                                child: const Text('הוספה'),
                                onPressed: () async {
                                  bool? isFromGraph = await showDialog(
                                    context: ctx,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Center(
                                            child: Text('הוספת תלות')),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              "בחר כיצד ברצונך להוסיף משימה שתלויה במשימה זו:",
                                            ),
                                            const SizedBox(height: 20),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceAround,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(true),
                                                  child: const Text(
                                                    "בחר משימה קיימת מהגרף",
                                                  ),
                                                ),
                                                const SizedBox(width: 20),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(false),
                                                  child: const Text(
                                                    "הוסף משימות חדשות",
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        actions: <Widget>[
                                          TextButton(
                                            child: const Text('ביטול'),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  );

                                  if (isFromGraph != null && isFromGraph) {
                                    // Disable selected the same node or direct dependencies
                                    List<String> disabledNodes =
                                        _combDependencies[taskID]!['FollowUps']!
                                            .toList();
                                    disabledNodes.addAll(_combDependencies[
                                        taskID]!['DependsOn']!);
                                    disabledNodes
                                        .addAll(_combDependencies.keys.where(
                                      (k) {
                                        var curComb = widget.nodes
                                            .singleWhere((e) => e.id == k);
                                        if (curComb.isFollowedByDecision) {
                                          return false;
                                        }

                                        // return _combDependencies[k]![
                                        //             'DependsOn']!
                                        //         .contains(combID) ||
                                        //     _combDependencies[k]!['FollowUps']!
                                        //         .contains(combID);
                                        return _combDependencies[k]![
                                                'DependsOn']!
                                            .contains(taskID);
                                      },
                                    ).map((e) => e.toString()));
                                    disabledNodes.add(taskID);
                                    String? chosenTask = await showDialog(
                                      context: ctx,
                                      builder: (context) {
                                        return AlertDialog(
                                          title: const Center(
                                            child: Text(
                                              'בחר משימה מהגרף שתלויה במשימה זו:',
                                            ),
                                          ),
                                          content: Flowchart(
                                            data: _nodes,
                                            flowChart: _flowChart,
                                            isSelection: true,
                                            disabledNodes: disabledNodes,
                                            onDeleteProcess: () {},
                                            onAddOrEditProcess: () {},
                                            onDeleteDecision: () {},
                                            onEditLinks: () {},
                                            onAddFromPredefined: () {},
                                            onSelected: (id) =>
                                                Navigator.of(context).pop(id),
                                          ),
                                          actions: <Widget>[
                                            TextButton(
                                              child: const Text('ביטול'),
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                    if (chosenTask != null) {
                                      debugPrint("Connecting to: $chosenTask");

                                      setState(() {
                                        _isLoadingChart = true;
                                      });
                                      setDialogState(() {
                                        isUpdatingDeps = true;
                                      });

                                      var taskA = widget.nodes
                                          .singleWhere((e) => e.id == taskID);
                                      var taskB = widget.nodes.singleWhere(
                                          (e) => e.id == chosenTask);
                                      CircularPathResponse cycleResponse =
                                          await _checkDependOnCircularPathFromGraph(
                                        [taskA, taskB],
                                        [taskID, chosenTask],
                                        chosenTask,
                                      );

                                      if (cycleResponse.isFound) {
                                        setDialogState(() {
                                          isUpdatingDeps = false;
                                        });
                                        setState(() {
                                          _isLoadingChart = false;
                                        });
                                        debugPrint("CIRCULAR PATH FOUND!:");
                                        _showCircularPathAlert(cycleResponse);
                                        return;
                                      }

                                      try {
                                        _combDependencies[taskID]!['DependsOn']!
                                            .add(chosenTask);
                                        await widget.onAddDependsOnDependency(
                                          id: taskID,
                                          dependsOnNodes: widget.nodes
                                              .where((e) => _combDependencies[
                                                      taskID]!['DependsOn']!
                                                  .contains(e.id))
                                              .toList(),
                                        );
                                        // await updatePredefinedTasksCombinationDependsOn(
                                        //   combID: taskID,
                                        //   dependsOnIDs: _combDependencies[
                                        //       taskID]!['DependsOn']!,
                                        // );
                                        _flowChart
                                            .singleWhere((e) =>
                                                e.id == chosenTask.toString())
                                            .next
                                            .add(
                                              EdgeInput(
                                                outcome: taskID,
                                              ),
                                            );
                                        // await dbProvider
                                        //     .addTaskCombination_DependsOn(
                                        //   TaskCombination_DependsOn(
                                        //     CombID: combID,
                                        //     DependsOnID: chosenTask,
                                        //   ),
                                        // );
                                        _buildGraph();
                                      } catch (e) {
                                        debugPrint(e.toString());
                                      } finally {
                                        setDialogState(() {
                                          isUpdatingDeps = false;
                                        });
                                        setState(() {
                                          _isLoadingChart = false;
                                        });
                                      }
                                    }
                                  }
                                  if (isFromGraph != null && !isFromGraph) {
                                    debugPrint("Choosing New Task");
                                    // var comb = widget.nodes.firstWhere(
                                    //   (e) => e.id == taskID,
                                    // );
                                    var result =
                                        await _showSelectPredefinedTasksDialog(
                                      title:
                                          "בחר את המשימות שמשימה זו תלויה בהן",
                                      preSelectedTasks:
                                          _combDependencies[taskID]
                                                  ?['FollowUps'] ??
                                              [],
                                      task: editedTask,
                                    );
                                    if (result['selectedPredefinedTasks'] !=
                                        null) {
                                      setState(() {
                                        _isLoadingChart = true;
                                      });
                                      setDialogState(() {
                                        isUpdatingDeps = true;
                                      });
                                      try {
                                        // var resMap =
                                        //     await addPredefinedTasksCombination(
                                        //   caseTypeId: comb_chosenCaseTypeId!,
                                        //   departmentId:
                                        //       comb_chosenDepartmentId!,
                                        //   predefinedTasksIDs:
                                        //       result['selectedPredefinedTasks'],
                                        // );
                                        Map<String, List<EdgeInput>> nextNodes =
                                            {};
                                        List<FlowchartNode> newTasks = [];
                                        // List<TaskCombination_X_PredefinedTasks>
                                        //     newCombs = [];
                                        for (String id in result[
                                            'selectedPredefinedTasks']) {
                                          // int combID = int.parse(
                                          //   resMap['mapping'][id.toString()],
                                          // );
                                          var newTask = widget.predefinedTasks
                                              .singleWhere((e) => e.id == id);

                                          // var newComb =
                                          //     TaskCombination_X_PredefinedTasks(
                                          //   ID: combID,
                                          //   CombinationID:
                                          //       comb_chosenCombinationId!,
                                          //   PredefinedTasksID: id,
                                          //   IsFollowedByDecision: false,
                                          //   DecisionQuestion: null,
                                          // );
                                          // await dbProvider
                                          //     .addTaskCombination_X_PredefinedTasks(
                                          //         newComb);
                                          // _taskCombination_X_PredefinedTasks
                                          //     .add(newComb);
                                          // newCombs.add(newComb);
                                          // nextNodes[combID] = [
                                          //   EdgeInput(
                                          //     outcome: comb.ID.toString(),
                                          //   ),
                                          // ];
                                          newTasks.add(newTask);
                                        }

                                        // _combDependencies[comb.ID]![
                                        //         'DependsOn']!
                                        //     .addAll(newCombs.map((e) => e.ID));
                                        // await updatePredefinedTasksCombinationDependsOn(
                                        //   combID: comb.ID,
                                        //   dependsOnIDs: _combDependencies[
                                        //       comb.ID]!['DependsOn']!,
                                        // );

                                        CircularPathResponse
                                            circularPathResponse =
                                            await _checkNewChunkCircularDependencies(
                                                newTasks);

                                        if (!circularPathResponse.isFound) {
                                          // Add dependencies recursively
                                          await widget.onPredefinedTasksAdded(
                                            predefinedTaskIds: result[
                                                'selectedPredefinedTasks'],
                                          );
                                          // await _insertFollowupsAndDependencies(
                                          //   result['selectedPredefinedTasks']
                                          //       as List<int>,
                                          //   resMap,
                                          //   newCombs,
                                          //   nextNodes,
                                          // );
                                        }

                                        // for (var p in newCombs) {
                                        //   var predefinedTask =
                                        //       _predefinedTasksData
                                        //           .singleWhere((e) =>
                                        //               e.ID ==
                                        //               p.PredefinedTasksID);
                                        //   _nodes[p.ID.toString()] = FlowStep(
                                        //     text: predefinedTask.Name,
                                        //     type: FlowStepType.process,
                                        //     isCompleted: false,
                                        //     isSkipped: false,
                                        //     canProgress: false,
                                        //   );
                                        //   _flowChart.add(
                                        //     NodeInput(
                                        //       id: p.ID.toString(),
                                        //       next: nextNodes[p.ID]!,
                                        //     ),
                                        //   );
                                        // }
                                        // comb_currentPredefinedTasks
                                        //     .addAll(newCombs);

                                        if (circularPathResponse.isFound) {
                                          debugPrint("CIRCULAR PATH FOUND!:");
                                          _showCircularPathAlert(
                                              circularPathResponse);
                                        } else {
                                          _buildGraph();
                                        }
                                      } catch (e) {
                                        debugPrint(e.toString());
                                      } finally {
                                        setDialogState(() {
                                          isUpdatingDeps = false;
                                        });
                                        setState(() {
                                          _isLoadingChart = false;
                                        });
                                      }
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(7.0),
                                    ),
                                    side: BorderSide(
                                      color: Colors.green,
                                      width: 2,
                                    ),
                                  ),
                                  foregroundColor: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          isUpdatingDeps
                              ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                              : Expanded(
                                  child: SingleChildScrollView(
                                    child: DataTable(
                                      horizontalMargin: 20,
                                      columnSpacing: 30,
                                      columns: [
                                        DataColumn(
                                          label: SizedBox(
                                            width: tableSize * 0.8,
                                            child: const Text(
                                              'שם משימה',
                                              style: TextStyle(fontSize: 16),
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: SizedBox(
                                            width: tableSize * 0.2,
                                            child: const Text(
                                              'פעולות',
                                              style: TextStyle(fontSize: 16),
                                            ),
                                          ),
                                        ),
                                      ],
                                      rows: _getRelationsDatarows(
                                        currentTask: editedTask,
                                        isFollowups: false,
                                        isFollowedByDecision: false,
                                        onUpdating: () => setDialogState(() {
                                          isUpdatingDeps = true;
                                        }),
                                        onDoneUpdating: () =>
                                            setDialogState(() {
                                          isUpdatingDeps = false;
                                        }),
                                      ),
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                    const Divider(height: 3, thickness: 3, color: Colors.black),
                    SizedBox(
                      height: deviceHeight * 0.37,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "משימות המשך למשימה זו:",
                                style: TextStyle(fontSize: 18),
                              ),
                              Row(
                                children: [
                                  ElevatedButton(
                                    child: Text(
                                      editedTask.isFollowedByDecision
                                          ? 'ביטול תלות בהחלטות'
                                          : 'הפוך המשך משימה ל-תלוי בהחלטה',
                                    ),
                                    onPressed: () async {
                                      bool? decision = await showDialog(
                                        context: ctx,
                                        builder: (context) {
                                          return AlertDialog(
                                            title: Center(
                                              child: Text(editedTask
                                                      .isFollowedByDecision
                                                  ? 'ביטול תלות בהחלטות'
                                                  : 'המשך משימה תלוי בהחלטה'),
                                            ),
                                            content: Text(
                                              editedTask.isFollowedByDecision
                                                  ? "האם אתה בטוח שברצונך לבטל את תלות המשימה בהחלטה?\nהקשר בין משימה זו למשימות העוקבות הנוכחיות יהפוך להמשך ישיר."
                                                  : "האם אתה בטוח שברצונך להפוך המשך משימה זו לתלוי בהחלטה?\nהקשר בין משימה זו למשימות ההמשך הנוכחיות יימחק.",
                                            ),
                                            actions: <Widget>[
                                              TextButton(
                                                child: const Text('ביטול'),
                                                onPressed: () {
                                                  Navigator.of(context)
                                                      .pop(false);
                                                },
                                              ),
                                              TextButton(
                                                child: const Text('אישור'),
                                                onPressed: () {
                                                  Navigator.of(context)
                                                      .pop(true);
                                                },
                                              ),
                                            ],
                                          );
                                        },
                                      );

                                      if (decision != null && decision) {
                                        setDialogState(() {
                                          isUpdatingFollowups = true;
                                        });
                                        if (editedTask.isFollowedByDecision) {
                                          await _convertFollowupToIndependent(
                                            editedTask.id,
                                          );
                                        } else {
                                          await _convertFollowupToDependent(
                                            editedTask,
                                          );
                                        }
                                        setDialogState(() {
                                          isUpdatingFollowups = false;
                                        });
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(7.0)),
                                        side: BorderSide(
                                          color: Colors.orange,
                                          width: 2,
                                        ),
                                      ),
                                      foregroundColor: Colors.orange,
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  ElevatedButton(
                                    child: Text(editedTask.isFollowedByDecision
                                        ? 'הוספת החלטה'
                                        : 'הוספה'),
                                    onPressed: () async {
                                      String userInput = '';
                                      if (editedTask.isFollowedByDecision) {
                                        final form = GlobalKey<FormState>(
                                            debugLabel: 'decision_name');
                                        String? name = await showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text(
                                              'הוספת החלטה',
                                              textAlign: TextAlign.center,
                                              textDirection: TextDirection.rtl,
                                            ),
                                            content: Form(
                                              key: form,
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Text(
                                                    "אנא הזן את שם ההחלטה\n",
                                                  ),
                                                  TextFormField(
                                                    decoration:
                                                        const InputDecoration(
                                                            hintText:
                                                                'שם החלטה'),
                                                    onChanged: (value) {
                                                      userInput = value;
                                                    },
                                                    initialValue: '',
                                                    validator: ((value) {
                                                      if (value == null ||
                                                          value.isEmpty) {
                                                        // allow saving if phone is entered and valid
                                                        if (userInput == null ||
                                                            userInput.isEmpty) {
                                                          return 'אנא הזן החלטה.';
                                                        }
                                                      }
                                                      return null;
                                                    }),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            actions: <Widget>[
                                              TextButton(
                                                child: const Text('אישור'),
                                                onPressed: () {
                                                  final isValid = form
                                                      .currentState!
                                                      .validate();
                                                  if (!isValid) {
                                                    return;
                                                  }
                                                  Navigator.of(ctx)
                                                      .pop(userInput);
                                                },
                                              ),
                                              TextButton(
                                                child: const Text('ביטול'),
                                                onPressed: () {
                                                  Navigator.of(ctx).pop(null);
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                        if (name != null && name.isNotEmpty) {
                                          userInput = name;
                                        } else {
                                          Navigator.of(context).pop();
                                        }
                                      }
                                      bool? isFromGraph = await showDialog(
                                        context: ctx,
                                        builder: (context) {
                                          return AlertDialog(
                                            title: Center(
                                              child: Text(
                                                editedTask.isFollowedByDecision
                                                    ? 'הוספת החלטה'
                                                    : 'הוספת משימת המשך',
                                              ),
                                            ),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Text(
                                                  "בחר כיצד ברצונך להוסיף משימת המשך למשימה זו:",
                                                ),
                                                const SizedBox(height: 20),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceAround,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    ElevatedButton(
                                                      onPressed: () =>
                                                          Navigator.of(context)
                                                              .pop(true),
                                                      child: const Text(
                                                        "בחר משימה קיימת מהגרף",
                                                      ),
                                                    ),
                                                    const SizedBox(width: 20),
                                                    ElevatedButton(
                                                      onPressed: () =>
                                                          Navigator.of(context)
                                                              .pop(false),
                                                      child: Text(
                                                        editedTask
                                                                .isFollowedByDecision
                                                            ? "הוסף משימה חדשה"
                                                            : "הוסף משימות חדשות",
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            actions: <Widget>[
                                              TextButton(
                                                child: const Text('ביטול'),
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                },
                                              ),
                                            ],
                                          );
                                        },
                                      );

                                      if (isFromGraph != null && isFromGraph) {
                                        // Disable selecting the same node or direct dependencies
                                        List<String> disabledNodes =
                                            _combDependencies[editedTask.id]![
                                                    'FollowUps']!
                                                .map((e) => e.toString())
                                                .toList();
                                        disabledNodes.addAll(_combDependencies[
                                                editedTask.id]!['DependsOn']!
                                            .map((e) => e.toString()));
                                        disabledNodes.addAll(
                                            _combDependencies.keys.where(
                                          (k) {
                                            var curComb = widget.nodes
                                                .singleWhere((e) => e.id == k);
                                            if (curComb.isFollowedByDecision) {
                                              return false;
                                            }
                                            return _combDependencies[k]![
                                                        'DependsOn']!
                                                    .contains(editedTask.id) ||
                                                _combDependencies[k]![
                                                        'FollowUps']!
                                                    .contains(editedTask.id);
                                          },
                                        ).map((e) => e.toString()));
                                        disabledNodes.add(editedTask.id);

                                        // Disable selecting nodes from decision trees
                                        List<String> preceededByDecision = [];
                                        var decisionNodes = _flowChart
                                            .where((f) =>
                                                f.id.contains("__FOLLOWUP"))
                                            .expand((e) =>
                                                e.next.map((n) => n.outcome))
                                            .toList();
                                        preceededByDecision
                                            .addAll(decisionNodes);
                                        for (var taskID in decisionNodes) {
                                          _addDecisionSubTreeRecursively(
                                            taskID,
                                            preceededByDecision,
                                          );
                                        }
                                        disabledNodes.addAll(
                                          preceededByDecision
                                              .map((e) => e.toString()),
                                        );

                                        String? chosenTaskId = await showDialog(
                                          context: ctx,
                                          builder: (context) {
                                            return AlertDialog(
                                              title: const Center(
                                                child: Text(
                                                  'בחר משימת המשך מהגרף:',
                                                ),
                                              ),
                                              content: Flowchart(
                                                data: _nodes,
                                                flowChart: _flowChart,
                                                isSelection: true,
                                                disabledNodes: disabledNodes,
                                                onDeleteProcess: () {},
                                                onAddOrEditProcess: () {},
                                                onDeleteDecision: () {},
                                                onEditLinks: () {},
                                                onAddFromPredefined: () {},
                                                onSelected: (id) =>
                                                    Navigator.of(context)
                                                        .pop(id),
                                              ),
                                              actions: <Widget>[
                                                TextButton(
                                                  child: const Text('ביטול'),
                                                  onPressed: () {
                                                    Navigator.of(context).pop();
                                                  },
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                        if (chosenTaskId != null) {
                                          debugPrint(
                                              "Connecting to: $chosenTaskId");

                                          setState(() {
                                            _isLoadingChart = true;
                                          });
                                          setDialogState(() {
                                            isUpdatingFollowups = true;
                                          });

                                          // var combA =
                                          //     comb_currentPredefinedTasks
                                          //         .singleWhere(
                                          //   (e) => e.ID == combID,
                                          // );
                                          // var taskA =
                                          //     _predefinedTasksData.singleWhere(
                                          //   (e) =>
                                          //       e.ID == combA.PredefinedTasksID,
                                          // );

                                          // var combB =
                                          //     comb_currentPredefinedTasks
                                          //         .singleWhere(
                                          //   (e) => e.ID == chosenTask,
                                          // );
                                          // var taskB =
                                          //     _predefinedTasksData.singleWhere(
                                          //   (e) =>
                                          //       e.ID == combB.PredefinedTasksID,
                                          // );
                                          var taskB = widget.nodes.singleWhere(
                                            (e) => e.id == chosenTaskId,
                                          );
                                          CircularPathResponse cycleResponse =
                                              await _checkFollowUpsCircularPathFromGraph(
                                            [editedTask, taskB],
                                            [editedTask.id, chosenTaskId],
                                            chosenTaskId,
                                          );

                                          if (cycleResponse.isFound) {
                                            setDialogState(() {
                                              isUpdatingFollowups = false;
                                            });
                                            setState(() {
                                              _isLoadingChart = false;
                                            });
                                            debugPrint("CIRCULAR PATH FOUND!:");
                                            _showCircularPathAlert(
                                              cycleResponse,
                                            );
                                            return;
                                          }

                                          try {
                                            _combDependencies[editedTask.id]![
                                                    'FollowUps']!
                                                .add(chosenTaskId);
                                            if (editedTask
                                                .isFollowedByDecision) {
                                              // await addPredefinedTasksCombinationDecisions(
                                              //   combID: combID,
                                              //   followUpsIDs: [
                                              //     TaskCombination_Decision(
                                              //       CombID: combID,
                                              //       Name: userInput,
                                              //       FollowUpID: chosenTaskId,
                                              //     ),
                                              //   ],
                                              // );
                                              await widget.onAddDecisionLink(
                                                id: editedTask.id,
                                                name: userInput,
                                                followupPredefinedTaskId:
                                                    chosenTaskId,
                                              );
                                              _flowChart
                                                  .singleWhere((e) =>
                                                      e.id ==
                                                      "${editedTask.id}__FOLLOWUP")
                                                  .next
                                                  .add(
                                                    EdgeInput(
                                                      outcome: chosenTaskId
                                                          .toString(),
                                                    ),
                                                  );
                                              var newDecision =
                                                  FlowchartDecisionNode(
                                                // nodeId: editedTask.id,
                                                answer: userInput,
                                                followupNodeId: chosenTaskId,
                                              );
                                              // await dbProvider
                                              //     .addTaskCombination_Decisions(
                                              //   newDecision,
                                              // );
                                              editedTask.decisionNodes!
                                                  .add(newDecision);
                                            } else {
                                              await widget
                                                  .onAddFollowUpDependency(
                                                id: editedTask.id,
                                                followUpNodes: widget.nodes
                                                    .where((e) =>
                                                        _combDependencies[
                                                                    taskID]![
                                                                'FollowUps']!
                                                            .contains(e.id))
                                                    .toList(),
                                              );
                                              // await updatePredefinedTasksCombinationFollowUps(
                                              //   combID: editekTask.id,
                                              //   followUpsIDs: _combDependencies[
                                              //       editekTask
                                              //           .id]!['FollowUps']!,
                                              // );
                                              _flowChart
                                                  .singleWhere((e) =>
                                                      e.id == editedTask.id)
                                                  .next
                                                  .add(
                                                    EdgeInput(
                                                      outcome: chosenTaskId
                                                          .toString(),
                                                    ),
                                                  );
                                              // await dbProvider
                                              //     .addTaskCombination_FollowUps(
                                              //   TaskCombination_FollowUps(
                                              //     CombID: editekTask.id,
                                              //     NextID: chosenTaskId,
                                              //   ),
                                              // );
                                            }
                                            _buildGraph();
                                          } catch (e) {
                                            debugPrint(e.toString());
                                          } finally {
                                            setDialogState(() {
                                              isUpdatingFollowups = false;
                                            });
                                            setState(() {
                                              _isLoadingChart = false;
                                            });
                                          }
                                        }
                                      }
                                      if (isFromGraph != null && !isFromGraph) {
                                        debugPrint("Choosing New Task");
                                        // var comb =
                                        //     _taskCombination_X_PredefinedTasks
                                        //         .firstWhere(
                                        //   (e) => e.ID == editekTask.id,
                                        // );
                                        // var comb = widget.nodes.firstWhere(
                                        //   (e) => e.id == taskID,
                                        // );
                                        Map result = {};
                                        if (editedTask.isFollowedByDecision) {
                                          // allow selecting only 1 task
                                          String? chosenFollowup;
                                          final form = GlobalKey<FormState>(
                                              debugLabel: 'decision_followup');
                                          var res = await showDialog(
                                            context: context,
                                            builder: (ctx) => StatefulBuilder(
                                              builder: (_, setDecisionsState) =>
                                                  AlertDialog(
                                                title: const Text(
                                                  'הוספת החלטה',
                                                  textAlign: TextAlign.center,
                                                  textDirection:
                                                      TextDirection.rtl,
                                                ),
                                                content: Form(
                                                  key: form,
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Text(
                                                        "אנא בחר את משימת ההמשך להחלטה זו:\n",
                                                      ),
                                                      DropdownButtonFormField<
                                                          String>(
                                                        hint: const Text(
                                                            "בחר משימת המשך"),
                                                        onChanged: (String?
                                                            newValue) async {
                                                          setDecisionsState(() {
                                                            chosenFollowup =
                                                                newValue;
                                                          });
                                                        },
                                                        items: widget
                                                            .predefinedTasks
                                                            .map((pt) =>
                                                                DropdownMenuItem<
                                                                    String>(
                                                                  value: pt.id,
                                                                  child: Text(
                                                                    pt.label,
                                                                  ),
                                                                ))
                                                            .toList(),
                                                        validator: (value) {
                                                          if (value == null) {
                                                            return 'אנא בחר אפשרות';
                                                          }
                                                          return null;
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                actions: <Widget>[
                                                  TextButton(
                                                    child: const Text('אישור'),
                                                    onPressed: () {
                                                      final isValid = form
                                                          .currentState!
                                                          .validate();
                                                      if (!isValid) {
                                                        return;
                                                      }
                                                      Navigator.of(ctx)
                                                          .pop(chosenFollowup);
                                                    },
                                                  ),
                                                  TextButton(
                                                    child: const Text('ביטול'),
                                                    onPressed: () {
                                                      Navigator.of(ctx)
                                                          .pop(null);
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                          if (res == null) {
                                            Navigator.of(context).pop();
                                          } else {
                                            result['selectedPredefinedTasks'] =
                                                [res as String];
                                          }
                                        } else {
                                          result =
                                              await _showSelectPredefinedTasksDialog(
                                            title:
                                                "בחר את משימות ההמשך הישירות אחרי המשימה הנוכחית",
                                            preSelectedTasks:
                                                _combDependencies[editedTask.id]
                                                        ?['FollowUps'] ??
                                                    [],
                                            task: editedTask,
                                          );
                                        }
                                        if (result['selectedPredefinedTasks'] !=
                                            null) {
                                          setState(() {
                                            _isLoadingChart = true;
                                          });
                                          setDialogState(() {
                                            isUpdatingFollowups = true;
                                          });
                                          try {
                                            // var resMap =
                                            //     await addPredefinedTasksCombination(
                                            //   caseTypeId:
                                            //       comb_chosenCaseTypeId!,
                                            //   departmentId:
                                            //       comb_chosenDepartmentId!,
                                            //   predefinedTasksIDs: result[
                                            //       'selectedPredefinedTasks'],
                                            // );
                                            Map<String, List<EdgeInput>>
                                                nextNodes = {};
                                            // List<FlowchartNode>
                                            //     newCombs = [];
                                            List<FlowchartNode> newTasks = [];
                                            for (String id in result[
                                                'selectedPredefinedTasks']) {
                                              // String combID =
                                              //     resMap['mapping'][id];
                                              // PredefinedTask newTask =
                                              //     _predefinedTasksData
                                              //         .singleWhere(
                                              //             (e) => e.ID == id);

                                              var newTask = widget
                                                  .predefinedTasks
                                                  .singleWhere(
                                                      (e) => e.id == id);

                                              // var newComb =
                                              //     TaskCombination_X_PredefinedTasks(
                                              //   ID: combID,
                                              //   CombinationID:
                                              //       comb_chosenCombinationId!,
                                              //   PredefinedTasksID: id,
                                              //   IsFollowedByDecision: false,
                                              //   DecisionQuestion: null,
                                              // );
                                              // await dbProvider
                                              //     .addTaskCombination_X_PredefinedTasks(
                                              //         newComb);
                                              // _taskCombination_X_PredefinedTasks
                                              //     .add(newComb);
                                              // newCombs.add(newComb);
                                              // nextNodes[combID] = [];
                                              newTasks.add(newTask);
                                            }

                                            // _combDependencies[comb.ID]![
                                            //         'FollowUps']!
                                            //     .addAll(
                                            //         newCombs.map((e) => e.ID));
                                            if (editedTask
                                                .isFollowedByDecision) {
                                              // var newDecision =
                                              //     TaskCombination_Decision(
                                              //   CombID: combID,
                                              //   Name: userInput,
                                              //   FollowUpID: resMap['mapping'][
                                              //       (result['selectedPredefinedTasks']
                                              //               as List<String>)
                                              //           .first],
                                              // );
                                              var newDecision =
                                                  FlowchartDecisionNode(
                                                // nodeId: editedTask.id,
                                                answer: userInput,
                                                followupNodeId:
                                                    (result['selectedPredefinedTasks']
                                                            as List<String>)
                                                        .first,
                                              );
                                              // await addPredefinedTasksCombinationDecisions(
                                              //   combID: combID,
                                              //   followUpsIDs: [newDecision],
                                              // );

                                              await widget.onAddDecisionLink(
                                                id: editedTask.id,
                                                name: userInput,
                                                followupPredefinedTaskId:
                                                    (result['selectedPredefinedTasks']
                                                            as List<String>)
                                                        .first,
                                              );

                                              // await dbProvider
                                              //     .addTaskCombination_Decisions(
                                              //         newDecision);
                                              // editedTask.decisionNodes!
                                              //     .add(newDecision);

                                              _flowChart
                                                  .singleWhere((e) =>
                                                      e.id ==
                                                      "${editedTask.id}__FOLLOWUP")
                                                  .next
                                                  .addAll(
                                                    newTasks.map(
                                                      (e) => EdgeInput(
                                                        outcome: e.id,
                                                      ),
                                                    ),
                                                  );

                                              for (var p in newTasks) {
                                                var predefinedTask = widget
                                                    .predefinedTasks
                                                    .singleWhere(
                                                        (e) => e.id == p.id);
                                                _nodes[p.id] = FlowStep(
                                                  text: predefinedTask.label,
                                                  type: FlowStepType.process,
                                                  isCompleted: false,
                                                  isSkipped: false,
                                                  canProgress: false,
                                                );
                                                _flowChart.add(
                                                  NodeInput(
                                                    id: p.id,
                                                    next: [],
                                                  ),
                                                );
                                              }
                                              _buildGraph();
                                            } else {
                                              // await updatePredefinedTasksCombinationFollowUps(
                                              //   combID: comb.ID,
                                              //   followUpsIDs: _combDependencies[
                                              //       comb.ID]!['FollowUps']!,
                                              // );

                                              // _flowChart
                                              //     .singleWhere((e) =>
                                              //         e.id ==
                                              //         comb.ID.toString())
                                              //     .next
                                              //     .addAll(
                                              //       newCombs.map(
                                              //         (e) => EdgeInput(
                                              //           outcome: e.id,
                                              //         ),
                                              //       ),
                                              //     );

                                              CircularPathResponse
                                                  circularPathResponse =
                                                  await _checkNewChunkCircularDependencies(
                                                      newTasks);

                                              if (!circularPathResponse
                                                  .isFound) {
                                                // Add dependencies recursively
                                                // await _insertFollowupsAndDependencies(
                                                //   result['selectedPredefinedTasks']
                                                //       as List<int>,
                                                //   resMap,
                                                //   newCombs,
                                                //   nextNodes,
                                                // );
                                                await widget
                                                    .onPredefinedTasksAdded(
                                                  predefinedTaskIds: result[
                                                      'selectedPredefinedTasks'],
                                                );
                                              }

                                              // for (var p in newCombs) {
                                              //   var predefinedTask =
                                              //       _predefinedTasksData
                                              //           .singleWhere((e) =>
                                              //               e.ID ==
                                              //               p.PredefinedTasksID);
                                              //   _nodes[p.ID.toString()] =
                                              //       FlowStep(
                                              //     text: predefinedTask.Name,
                                              //     type: FlowStepType.process,
                                              //     isCompleted: false,
                                              //     isSkipped: false,
                                              //     canProgress: false,
                                              //   );
                                              //   _flowChart.add(
                                              //     NodeInput(
                                              //       id: p.ID.toString(),
                                              //       next: nextNodes[p.ID]!,
                                              //     ),
                                              //   );
                                              // }

                                              if (circularPathResponse
                                                  .isFound) {
                                                debugPrint(
                                                    "CIRCULAR PATH FOUND!:");
                                                _showCircularPathAlert(
                                                    circularPathResponse);
                                              } else {
                                                _buildGraph();
                                              }
                                            }

                                            // comb_currentPredefinedTasks
                                            //     .addAll(newCombs);
                                            // widget.nodes.addAll(newTasks);
                                          } catch (e) {
                                            debugPrint(e.toString());
                                          } finally {
                                            setDialogState(() {
                                              isUpdatingFollowups = false;
                                            });
                                            setState(() {
                                              _isLoadingChart = false;
                                            });
                                          }
                                        }
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(7.0)),
                                        side: BorderSide(
                                          color: Colors.green,
                                          width: 2,
                                        ),
                                      ),
                                      foregroundColor: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (editedTask.isFollowedByDecision &&
                              !isUpdatingFollowups)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  const Text(
                                    "שאלה:",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    editedTask.decisionQuestion!,
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                  const SizedBox(width: 15),
                                  InkWell(
                                    child: const Icon(Icons.edit_rounded),
                                    onTap: () async {
                                      var userInput =
                                          editedTask.decisionQuestion!;
                                      final form = GlobalKey<FormState>(
                                          debugLabel: 'decision_question');
                                      String? name = await showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text(
                                            'עריכת שאלה',
                                            textAlign: TextAlign.center,
                                            textDirection: TextDirection.rtl,
                                          ),
                                          content: Form(
                                            key: form,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Text(
                                                  "אנא הזן את השאלה\n",
                                                ),
                                                TextFormField(
                                                  decoration:
                                                      const InputDecoration(
                                                          hintText: 'שאלה'),
                                                  onChanged: (value) {
                                                    userInput = value;
                                                  },
                                                  initialValue: userInput,
                                                  validator: ((value) {
                                                    if (value == null ||
                                                        value.isEmpty) {
                                                      if (userInput.isEmpty) {
                                                        return 'אנא הזן שאלה.';
                                                      }
                                                    }
                                                    return null;
                                                  }),
                                                ),
                                              ],
                                            ),
                                          ),
                                          actions: <Widget>[
                                            TextButton(
                                              child: const Text('אישור'),
                                              onPressed: () {
                                                final isValid = form
                                                    .currentState!
                                                    .validate();
                                                if (!isValid) {
                                                  return;
                                                }
                                                Navigator.of(ctx)
                                                    .pop(userInput);
                                              },
                                            ),
                                            TextButton(
                                              child: const Text('ביטול'),
                                              onPressed: () {
                                                Navigator.of(ctx).pop(null);
                                              },
                                            ),
                                          ],
                                        ),
                                      );
                                      if (name != null && name.isNotEmpty) {
                                        setDialogState(() {
                                          isUpdatingFollowups = true;
                                        });
                                        try {
                                          // await updatePredefinedTasksCombination(
                                          //   combID: editedTask.ID,
                                          //   isFollowedByDecision: true,
                                          //   decisionQuestion: name,
                                          // );
                                          await widget.onChangeDecisionQuestion(
                                            id: editedTask.id,
                                            newQuestion: name,
                                          );
                                          editedTask.decisionQuestion = name;
                                          // await dbProvider
                                          //     .updateTaskCombination_X_PredefinedTasks(
                                          //   id: editedTask.id,
                                          //   newVal: editedTask,
                                          // );
                                        } catch (e) {
                                          debugPrint(e.toString());
                                        } finally {
                                          setDialogState(() {
                                            isUpdatingFollowups = false;
                                          });
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          isUpdatingFollowups
                              ? const Center(child: CircularProgressIndicator())
                              : Expanded(
                                  child: SingleChildScrollView(
                                    child: DataTable(
                                      horizontalMargin: 20,
                                      columnSpacing: 30,
                                      columns: [
                                        if (editedTask.isFollowedByDecision)
                                          DataColumn(
                                            label: SizedBox(
                                              width: (tableSize - 30) * 0.4,
                                              child: const Text(
                                                'החלטה',
                                                style: TextStyle(fontSize: 16),
                                              ),
                                            ),
                                          ),
                                        DataColumn(
                                          label: SizedBox(
                                            width: (tableSize -
                                                    (editedTask
                                                            .isFollowedByDecision
                                                        ? 30
                                                        : 0)) *
                                                (editedTask.isFollowedByDecision
                                                    ? 0.4
                                                    : 0.8),
                                            child: Text(
                                              editedTask.isFollowedByDecision
                                                  ? 'משימת המשך'
                                                  : 'שם משימה',
                                              style:
                                                  const TextStyle(fontSize: 16),
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: SizedBox(
                                            width: (tableSize -
                                                    (editedTask
                                                            .isFollowedByDecision
                                                        ? 30
                                                        : 0)) *
                                                0.2,
                                            child: const Text(
                                              'פעולות',
                                              style: TextStyle(fontSize: 16),
                                            ),
                                          ),
                                        ),
                                      ],
                                      rows: _getRelationsDatarows(
                                        currentTask: editedTask,
                                        isFollowups: true,
                                        isFollowedByDecision:
                                            editedTask.isFollowedByDecision,
                                        onUpdating: () => setDialogState(() {
                                          isUpdatingFollowups = true;
                                        }),
                                        onDoneUpdating: () =>
                                            setDialogState(() {
                                          isUpdatingFollowups = false;
                                        }),
                                        allowDeleted: !editedTask
                                                .isFollowedByDecision ||
                                            _combDependencies[editedTask.id]![
                                                        'FollowUps']!
                                                    .length >
                                                2,
                                      ),
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddEditTaskDialogue(String? existingTaskID) {
    FlowchartNode? existingTask;
    var taskNameController = TextEditingController();
    var taskDescriptionController = TextEditingController();
    var daysToFinishController = TextEditingController();
    var taskDueDateController = TextEditingController();

    if (existingTaskID == null) {
      var initialDate = dateOutputFormat.format(
        DateTime.now().add(const Duration(days: defaultDaysToFinish)),
      );
      daysToFinishController.text = defaultDaysToFinish.toString();
      taskDueDateController.text = initialDate;
    } else {
      existingTask = widget.nodes.singleWhere((e) => e.id == existingTaskID);
      taskNameController.text = existingTask.label;
      taskDescriptionController.text = existingTask.description ?? "";
      daysToFinishController.text = existingTask.daysToFinish?.toString() ??
          defaultDaysToFinish.toString();
      taskDueDateController.text = existingTask.dueDate == null
          ? "טרם נקבע"
          : dateOutputFormat.format(existingTask.dueDate!);
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existingTaskID == null ? 'הוספת משימה' : 'עריכת משימה'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: taskNameController,
                    decoration: const InputDecoration(
                      labelText: 'שם משימה',
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue, width: 2.0),
                      ),
                      prefixIcon: Icon(Icons.business),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: taskDescriptionController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'תיאור',
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.green, width: 2.0),
                      ),
                      prefixIcon: Icon(Icons.description),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: taskDueDateController,
                    decoration: InputDecoration(
                      labelText: 'תאריך אחרון לסיום',
                      border: const OutlineInputBorder(),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue, width: 2.0),
                      ),
                      prefixIcon: const Icon(Icons.date_range_rounded),
                      filled: existingTaskID != null &&
                          existingTask!.dueDate == null,
                      fillColor: const Color.fromARGB(255, 203, 203, 203),
                    ),
                    onTap:
                        existingTaskID != null && existingTask!.dueDate == null
                            ? null
                            : () => _showDatePicker(
                                  taskDueDateController,
                                  daysToFinishController,
                                ),
                    readOnly:
                        existingTaskID != null && existingTask!.dueDate == null,
                  ),
                ),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: 8.0, bottom: 3.0),
                    child: Text('- או -'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: daysToFinishController,
                    decoration: const InputDecoration(
                      labelText: 'מספר ימים לסיום',
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue, width: 2.0),
                      ),
                      prefixIcon: Icon(Icons.access_time_rounded),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      if (val.isNotEmpty) {
                        int days = int.parse(val);
                        taskDueDateController.text = dateOutputFormat.format(
                          DateTime.now().add(Duration(days: days)),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () async {
                if (existingTaskID == null) {
                  await widget.onSingleTaskAdded(
                    daysToFinish: daysToFinishController.text.isEmpty
                        ? null
                        : int.parse(daysToFinishController.text),
                    description: taskDescriptionController.text,
                    dueDate: dateOutputFormat.parse(taskDueDateController.text),
                    label: taskNameController.text,
                    status: FlowNodeStatus.inProgress,
                  );
                  // var newTask = FlowchartNode(
                  //   // caseID: widget.casee.ID,
                  //   label: taskNameController.text,
                  //   description: taskDescriptionController.text,
                  //   dueDate: dateOutputFormat.parse(taskDueDateController.text),
                  //   status: FlowNodeStatus.inProgress,
                  //   daysToFinish: daysToFinishController.text.isEmpty
                  //       ? null
                  //       : int.parse(daysToFinishController.text),
                  // );

                  // // Add to Graph
                  // widget.nodes.add(newTask);
                  // await dbProvider.addTask(newTask);
                  _buildGraph();

                  Navigator.of(context).pop();
                  debugPrint("Added Task Successfully");
                  _showSnackbar(
                    context,
                    "המשימה נוספה בהצלחה",
                    backgroundColor: Colors.green,
                  );
                } else {
                  // await updateTask(
                  //   id: existingTaskID,
                  //   updatedTask: existingTask!,
                  // );
                  // await dbProvider.updateTask(
                  //   id: existingTaskID,
                  //   newVal: existingTask,
                  // );
                  existingTask!.daysToFinish =
                      daysToFinishController.text.isEmpty
                          ? null
                          : int.parse(daysToFinishController.text);
                  existingTask.description = taskDescriptionController.text;
                  existingTask.dueDate =
                      taskDueDateController.text == "טרם נקבע"
                          ? null
                          : dateOutputFormat.parse(taskDueDateController.text);
                  existingTask.label = taskNameController.text;
                  await widget.onTaskDetailsUpdated(updatedNode: existingTask);
                  _buildGraph();
                  Navigator.of(context).pop();
                  debugPrint("Task Updated Successfully");
                  _showSnackbar(
                    context,
                    "המשימה עודכנה בהצלחה",
                    backgroundColor: Colors.green,
                  );
                }
              },
              child: Text(existingTaskID == null ? 'הוספה' : 'עריכה'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isLoadingChart
        ? const Center(child: CircularProgressIndicator())
        : Flowchart(
            data: _nodes,
            flowChart: _flowChart,
            onAddOrEditProcess: _showAddEditTaskDialogue,
            onEditLinks: _onEditLinks,
            onDeleteProcess: _onDeleteTask,
            onDeleteDecision: _convertFollowupToIndependent,
            onCompleteTask: _onCompleteTask,
            onAddFromPredefined: _onAddFromPredefinedTasks,
            displayOnly: widget.displayType == FlowDisplayType.displayOnly,
          );
  }
}

class FlowchartNode {
  final String id;
  String label;
  final List<FlowchartNode> dependsOnNodes;
  final List<FlowchartNode> followupNodes;
  bool isFollowedByDecision;
  String? decisionQuestion;
  String? decisionAnswer;
  List<FlowchartDecisionNode>? decisionNodes;
  DateTime? dueDate;
  int? daysToFinish;
  String? description;

  final FlowStepType type;
  FlowNodeStatus status;
  // bool isCompleted;
  // bool isSkipped;
  bool _canProgress = true;

  get isCompleted => status == FlowNodeStatus.completed;
  get isSkipped => status == FlowNodeStatus.skipped;

  FlowchartNode({
    required this.id,
    required this.label,
    // required this.isCompleted,
    // required this.isSkipped,
    required this.status,
    required this.type,
    this.isFollowedByDecision = false,
    this.decisionQuestion,
    this.decisionAnswer,
    this.dueDate,
    this.daysToFinish,
    this.description,
    List<FlowchartNode>? dependsOnNodes,
    List<FlowchartNode>? followupNodes,
    List<FlowchartDecisionNode>? decisionNodes,
  })  : dependsOnNodes = dependsOnNodes ?? [],
        followupNodes = followupNodes ?? [],
        decisionNodes = decisionNodes ?? [] {
    if (isFollowedByDecision && decisionQuestion == null) {
      throw ArgumentError(
          'decisionQuestion cannot be null when isFollowedByDecision is true');
    }
    if (isFollowedByDecision && decisionQuestion == null) {
      throw ArgumentError(
          'decisionQuestion cannot be null when isFollowedByDecision is true');
    }
  }

  void martkAsCanProgress() {
    _canProgress = true;
  }

  void martkAsCantProgress() {
    _canProgress = false;
  }

  bool get canProgress {
    if (isCompleted || isSkipped) {
      return false;
    }
    if (dependsOnNodes.isNotEmpty) {
      return dependsOnNodes.every((node) => node.isCompleted || node.isSkipped);
    }
    return _canProgress;
  }

  void markAsCompleted() {
    status = FlowNodeStatus.completed;
    _canProgress = false;
  }

  void markAsSkipped() {
    status = FlowNodeStatus.skipped;
    _canProgress = false;
  }

  void markAsNotCompleted() {
    status = FlowNodeStatus.inProgress;
    _canProgress = true;
  }

  void markAsNotSkipped() {
    status = FlowNodeStatus.inProgress;
    _canProgress = true;
  }
}

class FlowchartDecisionNode {
  // final String nodeId;
  String answer;
  String followupNodeId;

  FlowchartDecisionNode({
    // required this.nodeId,
    required this.answer,
    required this.followupNodeId,
  });
}

// Example Screen
// class FlowchartExampleScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final List<FlowchartNode> exampleNodes = [
//       FlowchartNode(
//         id: '1',
//         label: 'Start',
//         status: FlowNodeStatus.inProgress,
//         type: FlowStepType.process,
//         followupNodes: [
//           FlowchartNode(
//             id: '2',
//             label: 'Task 1',
//             status: FlowNodeStatus.inProgress,
//             type: FlowStepType.process,
//           ),
//         ],
//       ),
//       FlowchartNode(
//         id: '2',
//         label: 'Task 1',
//         status: FlowNodeStatus.inProgress,
//         type: FlowStepType.process,
//         followupNodes: [
//           FlowchartNode(
//             id: '3',
//             label: 'Task 2',
//             status: FlowNodeStatus.inProgress,
//             type: FlowStepType.process,
//           ),
//         ],
//       ),
//       FlowchartNode(
//         id: '3',
//         label: 'Task 2',
//         status: FlowNodeStatus.inProgress,
//         type: FlowStepType.process,
//       ),
//     ];

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Flowchart Example'),
//       ),
//       body: Center(
//         child: SizedBox(
//           height: MediaQuery.of(context).size.height * 0.8,
//           width: MediaQuery.of(context).size.width * 0.8,
//           child: FlowchartGraph(
//             nodes: exampleNodes,
//             displayType: FlowDisplayType.displayOnly,
//             onTaskStatusChanged: ({
//               required String id,
//               required FlowNodeStatus newStatus,
//               required List<FlowchartNode> updatedNodes,
//             }) {
//               // Handle task status change
//               debugPrint('');
//             },
//             onTaskCompleted: ({
//               required String id,
//               required List<FlowchartNode> updatedNodes,
//             }) {
//               // Handle task completion
//               debugPrint('');
//             },
//             onTaskDeleted: ({
//               required String id,
//               required List<FlowchartNode> updatedNodes,
//             }) {
//               // Handle task deletion
//               debugPrint('');
//             },
//             onFlowUpdated: ({
//               required List<FlowchartNode> updatedNodes,
//             }) {
//               // Handle flow update
//               debugPrint('');
//             },
//             onSingleTaskAdded: ({
//               required String label,
//               required String description,
//               required DateTime dueDate,
//               required FlowNodeStatus status,
//               int? daysToFinish,
//             }) {
//               // Handle task addition
//               debugPrint('');
//             },
//           ),
//         ),
//       ),
//     );
//   }
// }
