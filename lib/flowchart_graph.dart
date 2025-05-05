import 'package:flutter/material.dart';
import 'package:graphite/graphite.dart';
import 'package:intl/intl.dart';
import 'flowchart.dart';

enum FlowDisplayType { flow, displayOnly, select }

enum FlowNodeStatus { inProgress, completed, skipped, blocked }

final dateOutputFormat = DateFormat('dd/MM/yyyy');

const int defaultDaysToFinish = 7;

class FlowchartGraph extends StatefulWidget {
  final List<FlowchartNode> nodes;

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

  // A function that is called when something in the graph is updated (link added/removed)
  // Receives the list of nodes that were updated in the graph
  final Function({required List<FlowchartNode> updatedNodes}) onFlowUpdated;

  // A function that is called when the flow is completed
  final Function? onFlowCompleted;

  // A function that is called when a task is added
  final Function({
    required String label,
    required String description,
    required DateTime dueDate,
    required FlowNodeStatus status,
    int? daysToFinish,
  }) onTaskAdded;

  final FlowDisplayType displayType;

  FlowchartGraph({
    required this.nodes, // currentPredefinedTasks
    required this.onTaskStatusChanged,
    required this.onTaskCompleted,
    required this.onTaskDeleted,
    required this.onFlowUpdated,
    required this.displayType,
    required this.onTaskAdded,
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
      var decisionsIds = curTaskDecisions?.map((e) => e.nodeId).toList();
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

  void _updateGraphProgress() {
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
          widget.onTaskStatusChanged(
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
      widget.onTaskStatusChanged(
        id: resetTask.id,
        newStatus: FlowNodeStatus.blocked,
        updatedNodes: [resetTask],
      );
    }

    if (_getIsFlowCompleted()) {
      widget.onFlowCompleted?.call();
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
    widget.onTaskStatusChanged(
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
              widget.nodes.singleWhere((t) => t.id == decision.nodeId);
          _markPathSkippedRecursively(decision_task);
        }
      }

      // await dbProvider.updateTask(id: taskID, newVal: task);
      _nodes[taskID]!.isCompleted = true;
      widget.onTaskCompleted(id: taskID, updatedNodes: [task]);
      _updateGraphProgress();
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
      widget.onTaskDeleted(id: taskID, updatedNodes: modifiedNodes);
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
                  widget.onTaskAdded(
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
                  widget.onFlowUpdated(updatedNodes: [existingTask!]);
                  Navigator.of(context).pop();
                  debugPrint("Added Updated Successfully");
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
            onEditProcess: _showAddEditTaskDialogue,
            onDeleteProcess: _onDeleteTask,
            onDeleteDecision: () {}, // TODO
            onCompleteTask: _onCompleteTask,
            displayOnly: widget.displayType == FlowDisplayType.displayOnly,
          );
  }
}

class FlowchartNode {
  final String id;
  final String label;
  final List<FlowchartNode> dependsOnNodes;
  final List<FlowchartNode> followupNodes;
  final bool isFollowedByDecision;
  final String? decisionQuestion;
  String? decisionAnswer;
  final List<FlowchartDecisionNode>? decisionNodes;
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
    this.dependsOnNodes = const [],
    this.followupNodes = const [],
    this.decisionNodes = const [],
  }) {
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
  final String nodeId;
  final String answer;

  FlowchartDecisionNode({
    required this.nodeId,
    required this.answer,
  });
}

// Example Screen
class FlowchartExampleScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final List<FlowchartNode> exampleNodes = [
      FlowchartNode(
        id: '1',
        label: 'Start',
        status: FlowNodeStatus.inProgress,
        type: FlowStepType.process,
        followupNodes: [
          FlowchartNode(
            id: '2',
            label: 'Task 1',
            status: FlowNodeStatus.inProgress,
            type: FlowStepType.process,
          ),
        ],
      ),
      FlowchartNode(
        id: '2',
        label: 'Task 1',
        status: FlowNodeStatus.inProgress,
        type: FlowStepType.process,
        followupNodes: [
          FlowchartNode(
            id: '3',
            label: 'Task 2',
            status: FlowNodeStatus.inProgress,
            type: FlowStepType.process,
          ),
        ],
      ),
      FlowchartNode(
        id: '3',
        label: 'Task 2',
        status: FlowNodeStatus.inProgress,
        type: FlowStepType.process,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flowchart Example'),
      ),
      body: Center(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          width: MediaQuery.of(context).size.width * 0.8,
          child: FlowchartGraph(
            nodes: exampleNodes,
            displayType: FlowDisplayType.displayOnly,
            onTaskStatusChanged: ({
              required String id,
              required FlowNodeStatus newStatus,
              required List<FlowchartNode> updatedNodes,
            }) {
              // Handle task status change
              debugPrint('');
            },
            onTaskCompleted: ({
              required String id,
              required List<FlowchartNode> updatedNodes,
            }) {
              // Handle task completion
              debugPrint('');
            },
            onTaskDeleted: ({
              required String id,
              required List<FlowchartNode> updatedNodes,
            }) {
              // Handle task deletion
              debugPrint('');
            },
            onFlowUpdated: ({
              required List<FlowchartNode> updatedNodes,
            }) {
              // Handle flow update
              debugPrint('');
            },
            onTaskAdded: ({
              required String label,
              required String description,
              required DateTime dueDate,
              required FlowNodeStatus status,
              int? daysToFinish,
            }) {
              // Handle task addition
              debugPrint('');
            },
          ),
        ),
      ),
    );
  }
}
