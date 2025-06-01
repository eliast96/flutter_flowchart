import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'flowchart.dart';
import 'flowchart_graph.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      locale: const Locale('he'),
      // supportedLocales: languageModel.supportedLocales,
      supportedLocales: const [
        Locale('he'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var _displayType = FlowDisplayType.displayOnly;

  final List<FlowchartNode> predefinedTasks = [
    FlowchartNode(
      id: '4',
      label: 'Predefined Task 1',
      status: FlowNodeStatus.inProgress,
      type: FlowStepType.process,
      followupNodes: [
        FlowchartNode(
          id: '5',
          label: 'Predefined Task 2',
          status: FlowNodeStatus.inProgress,
          type: FlowStepType.process,
        ),
      ],
    ),
    FlowchartNode(
      id: '5',
      label: 'Predefined Task 2',
      status: FlowNodeStatus.inProgress,
      type: FlowStepType.process,
      followupNodes: [
        FlowchartNode(
          id: '6',
          label: 'Predefined Task 3',
          status: FlowNodeStatus.inProgress,
          type: FlowStepType.process,
        ),
      ],
    ),
    FlowchartNode(
      id: '6',
      label: 'Predefined Task 3',
      status: FlowNodeStatus.inProgress,
      type: FlowStepType.process,
    ),
  ];

  final List<FlowchartNode> _exampleNodes = [
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

  Future<Map<String, String>> _insertPredefinedTasksToGraph(
    List<String> predefinedTaskIDs,
  ) async {
    Map<String, String> tasksMapping = {};
    for (String predefinedTaskID in predefinedTaskIDs) {
      var taskID = 'newid_${DateTime.now().millisecondsSinceEpoch}';
      var predefinedTask =
          predefinedTasks.singleWhere((e) => e.id == predefinedTaskID);
      await Future.delayed(const Duration(milliseconds: 1));
      var newNode = FlowchartNode(
        id: taskID,
        label: predefinedTask.label,
        status: FlowNodeStatus.inProgress,
        type: predefinedTask.type,
        daysToFinish: predefinedTask.daysToFinish,
        description: predefinedTask.description,
      );
      _exampleNodes.add(newNode);
      tasksMapping[predefinedTaskID] = taskID;
    }
    return tasksMapping;
  }

  Future<void> _insertFollowupsAndDependencies(
    List<String> predefinedTaskIDs,
    Map<String, String> tasksMapping,
    // List<FlowchartNode> newCombs,
    // Map<String, List<EdgeInput>> nextNodes,
  ) async {
    for (String predefinedTaskID in predefinedTaskIDs) {
      // Create dependencies
      List<String> dependsOnIDs = predefinedTasks
          .singleWhere((e) => e.id == predefinedTaskID)
          .dependsOnNodes
          .map((e) => e.id)
          .toList();
      List<String> followUpsIDs = predefinedTasks
          .singleWhere((e) => e.id == predefinedTaskID)
          .followupNodes
          .map((e) => e.id)
          .toList();
      String taskID = '';
      FlowchartNode? currentTask;
      if (tasksMapping.containsKey(predefinedTaskID)) {
        taskID = tasksMapping[predefinedTaskID]!;
        currentTask = _exampleNodes.singleWhere((e) => e.id == taskID);
      } else {
        // If the task is not in the mapping, it means it is a new task
        // and we need to create a new combination for it
        taskID = 'newid_${DateTime.now().millisecondsSinceEpoch}';
        var predefinedTask =
            predefinedTasks.singleWhere((e) => e.id == predefinedTaskID);
        await Future.delayed(const Duration(milliseconds: 1));
        var newNode = FlowchartNode(
          id: taskID,
          label: predefinedTask.label,
          status: FlowNodeStatus.inProgress,
          type: predefinedTask.type,
          daysToFinish: predefinedTask.daysToFinish,
          description: predefinedTask.description,
        );
        _exampleNodes.add(newNode);
        tasksMapping[predefinedTaskID] = taskID;
        currentTask = newNode;
      }

      // recursively add FollowUps & DependsOn to TaskCombinations
      var followupsResMap = {};
      var dependsOnResMap = {};
      List<String> newFollowups = [];
      List<String> newDependsOns = [];
      if (followUpsIDs.isNotEmpty) {
        var newFollowupsOnly = followUpsIDs
            .where((e) => // do not add task if already exists, add link instead
                !tasksMapping.containsKey(e))
            .toList();
        // followupsResMap = await addPredefinedTasksCombination(
        //   caseTypeId: comb_chosenCaseTypeId!,
        //   departmentId: comb_chosenDepartmentId!,
        //   predefinedTasksIDs: newFollowupsOnly,
        //   isFollowedByDecision: false,
        //   decisionQuestion: null,
        // );

        // for (var id in newFollowupsOnly) {
        //   var newCombID = int.parse(followupsResMap['mapping'][id.toString()]);
        //   var newComb = TaskCombination_X_PredefinedTasks(
        //     ID: newCombID,
        //     CombinationID: comb_chosenCombinationId!,
        //     PredefinedTasksID: id,
        //     IsFollowedByDecision: false,
        //     DecisionQuestion: null,
        //   );
        //   await dbProvider.addTaskCombination_X_PredefinedTasks(newComb);
        //   _taskCombination_X_PredefinedTasks.add(newComb);
        //   newCombs.add(newComb);
        //   nextNodes[newCombID] = [];
        // }
        // nextNodes[taskID]!.addAll(newFollowups.map(
        //   (e) => EdgeInput(outcome: e.toString()),
        // ));
        // for (var followup in newFollowups) {
        //   await dbProvider.addTaskCombination_FollowUps(
        //     TaskCombination_FollowUps(CombID: taskID, NextID: followup),
        //   );
        // }
        await _insertFollowupsAndDependencies(
          newFollowupsOnly,
          tasksMapping,
          // newCombs,
          // nextNodes,
        );

        // var alreadyInserted = followUpsIDs
        //     .where((e) => tasksMapping.containsKey(e))
        //     .map((e) => tasksMapping[e]!)
        //     .toList();
        // newFollowups = newFollowupsOnly.map((e) => tasksMapping[e]!).toList()
        //   ..addAll(alreadyInserted);
        // await updatePredefinedTasksCombinationFollowUps(
        //   combID: taskID,
        //   followUpsIDs: newFollowups,
        // );
        var taskIDsToAdd = followUpsIDs.map((e) => tasksMapping[e]!);
        currentTask.followupNodes
            .addAll(_exampleNodes.where((n) => taskIDsToAdd.contains(n.id)));
      }
      debugPrint("Added all followups.");
      // if (dependsOnIDs.isNotEmpty) {
      //   var newDepsOnly = dependsOnIDs
      //       .where((e) => // do not add task if already exists, add link instead
      //           // !comb_currentPredefinedTasks
      //           //     .any((t) => t.PredefinedTasksID == e) &&
      //           !newCombs.any((t) => t.PredefinedTasksID == e))
      //       .toList();
      //   dependsOnResMap = await addPredefinedTasksCombination(
      //     caseTypeId: comb_chosenCaseTypeId!,
      //     departmentId: comb_chosenDepartmentId!,
      //     predefinedTasksIDs: newDepsOnly,
      //     isFollowedByDecision: false,
      //     decisionQuestion: null,
      //   );

      //   var alreadyInserted = dependsOnIDs
      //       .where((e) => newCombs.any((t) => t.PredefinedTasksID == e))
      //       .map(
      //           (e) => newCombs.singleWhere((c) => c.PredefinedTasksID == e).ID)
      //       .toList();
      //   newDependsOns = newDepsOnly
      //       .map((e) => int.parse(dependsOnResMap['mapping'][e.toString()]))
      //       .toList()
      //     ..addAll(alreadyInserted);
      //   await updatePredefinedTasksCombinationDependsOn(
      //     combID: taskID,
      //     dependsOnIDs: newDependsOns,
      //   );

      //   for (var id in newDepsOnly) {
      //     var newCombID = int.parse(dependsOnResMap['mapping'][id.toString()]);
      //     var newComb = TaskCombination_X_PredefinedTasks(
      //       ID: newCombID,
      //       CombinationID: comb_chosenCombinationId!,
      //       PredefinedTasksID: id,
      //       IsFollowedByDecision: false,
      //       DecisionQuestion: null,
      //     );
      //     await dbProvider.addTaskCombination_X_PredefinedTasks(newComb);
      //     _taskCombination_X_PredefinedTasks.add(newComb);
      //     newCombs.add(newComb);
      //     nextNodes[newCombID] = [];
      //     nextNodes[newCombID]!.add(
      //       EdgeInput(outcome: taskID.toString()),
      //     );
      //     await dbProvider.addTaskCombination_DependsOn(
      //       TaskCombination_DependsOn(CombID: taskID, DependsOnID: newCombID),
      //     );
      //   }
      //   for (var id in alreadyInserted) {
      //     nextNodes[id]!.add(
      //       EdgeInput(outcome: taskID.toString()),
      //     );
      //     await dbProvider.addTaskCombination_DependsOn(
      //       TaskCombination_DependsOn(CombID: taskID, DependsOnID: id),
      //     );
      //   }
      //   await _insertFollowupsAndDependencies(
      //     newDepsOnly,
      //     dependsOnResMap,
      //     newCombs,
      //     nextNodes,
      //   );
      // }

      // _combDependencies[taskID] = {
      //   'DependsOn': newDependsOns,
      //   'FollowUps': newFollowups,
      // };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          width: MediaQuery.of(context).size.width * 0.8,
          child: Stack(
            children: [
              FlowchartGraph(
                nodes: _exampleNodes,
                displayType: _displayType,
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
                onTaskDetailsUpdated: ({
                  required FlowchartNode updatedNode,
                }) {
                  // Handle flow update
                  debugPrint('Task Updated');
                },
                onSingleTaskAdded: ({
                  required String label,
                  required String description,
                  required DateTime dueDate,
                  required FlowNodeStatus status,
                  int? daysToFinish,
                }) {
                  // Handle task addition
                  var newNode = FlowchartNode(
                    id: 'newid_${DateTime.now().millisecondsSinceEpoch}',
                    label: label,
                    status: FlowNodeStatus.inProgress,
                    type: FlowStepType.process,
                    daysToFinish: daysToFinish,
                    dueDate: dueDate,
                    description: description,
                  );
                  setState(() {
                    _exampleNodes.add(newNode);
                  });
                  debugPrint('Task Added');
                },
                onAddDecisionLink: ({
                  required String id,
                  required String followupPredefinedTaskId,
                  required String name,
                }) async {
                  debugPrint("onAddDecisionLink");
                  var editedNode = _exampleNodes.singleWhere((e) => e.id == id);

                  // Insert new predefined tasks and then map them as followups
                  var mapping = await _insertPredefinedTasksToGraph(
                      [followupPredefinedTaskId]);
                  editedNode.decisionNodes!.add(
                    FlowchartDecisionNode(
                      answer: name,
                      followupNodeId: mapping[followupPredefinedTaskId]!,
                    ),
                  );
                  setState(() {});
                },
                onAddDependsOnDependency: ({
                  required String id,
                  required List<FlowchartNode> dependsOnNodes,
                }) {
                  debugPrint("onAddDependsOnDependency");
                  var editedNode = _exampleNodes.singleWhere((e) => e.id == id);
                  setState(() {
                    editedNode.dependsOnNodes.addAll(dependsOnNodes);
                  });
                },
                onAddFollowUpDependency: ({
                  required String id,
                  required List<FlowchartNode> followUpNodes,
                }) {
                  debugPrint("onAddFollowUpDependency");
                  var editedNode = _exampleNodes.singleWhere((e) => e.id == id);
                  setState(() {
                    editedNode.followupNodes.addAll(followUpNodes);
                  });
                },
                onChangeDecisionQuestion: ({
                  required String id,
                  required String newQuestion,
                }) {
                  debugPrint("onChangeDecisionQuestion");
                },
                onConvertFollowupToDecision: ({
                  required String taskId,
                  required String question,
                  required Map answers,
                  required Map followupIDs,
                }) async {
                  debugPrint("onConvertFollowupToDecision");
                  var editedNode =
                      _exampleNodes.singleWhere((e) => e.id == taskId);

                  // Insert new predefined tasks and then map them as followups
                  var mapping = await _insertPredefinedTasksToGraph(
                    List<String>.from(followupIDs.values),
                  );

                  editedNode.followupNodes.clear();
                  editedNode.isFollowedByDecision = true;
                  editedNode.decisionQuestion = question;
                  List<FlowchartDecisionNode> decisionNodes = [];
                  for (var key in answers.keys) {
                    decisionNodes.add(
                      FlowchartDecisionNode(
                        answer: answers[key],
                        followupNodeId: mapping[followupIDs[key]]!,
                      ),
                    );
                  }
                  editedNode.decisionNodes = [];
                  editedNode.decisionNodes!.addAll(decisionNodes);
                  setState(() {});
                },
                onPredefinedTasksAdded: ({
                  required List<String> predefinedTaskIds,
                }) async {
                  debugPrint("onPredefinedTasksAdded");
                  await _insertPredefinedTasksToGraph(predefinedTaskIds);
                },
                onRemoveDecisionLink: ({
                  required String id,
                  required String name,
                }) {
                  debugPrint("onRemoveDecisionLink");
                  var editedNode = _exampleNodes.singleWhere((e) => e.id == id);
                  editedNode.decisionNodes!.removeWhere(
                    (e) => e.answer == name,
                  );
                  setState(() {});
                },
                onRemoveDecisionNode: ({
                  required String taskId,
                }) {
                  debugPrint("onRemoveDecisionNode");
                  // Need to remove just the decision node but keep the children whitout links
                  var editedNode =
                      _exampleNodes.singleWhere((e) => e.id == taskId);
                  editedNode.isFollowedByDecision = false;
                  editedNode.decisionQuestion = null;
                  editedNode.decisionAnswer = null;
                  editedNode.decisionNodes!.clear();
                  setState(() {});
                },
                onRemoveDependOnLink: ({
                  required String id,
                  required String dependsOnId,
                }) {
                  debugPrint("onRemoveDependOnLink");
                  var editedNode = _exampleNodes.singleWhere((e) => e.id == id);
                  setState(() {
                    editedNode.dependsOnNodes
                        .removeWhere((e) => e.id == dependsOnId);
                  });
                },
                onRemoveFollowUpLink: ({
                  required String id,
                  required String followupId,
                }) {
                  debugPrint("onRemoveFollowUpLink");
                  var editedNode = _exampleNodes.singleWhere((e) => e.id == id);
                  setState(() {
                    editedNode.followupNodes
                        .removeWhere((e) => e.id == followupId);
                  });
                },
                predefinedTasks: predefinedTasks,
                onFlowCompleted: () {
                  // Handle flow completion
                  debugPrint("Flow Completed");
                },
              ),
              Positioned(
                bottom: 20,
                right: 20,
                child: FloatingActionButton(
                  onPressed: () {
                    setState(() {
                      _displayType = _displayType == FlowDisplayType.displayOnly
                          ? FlowDisplayType.flow
                          : FlowDisplayType.displayOnly;
                    });
                  },
                  tooltip: 'Toggle Display Type',
                  child: Icon(
                    _displayType == FlowDisplayType.displayOnly
                        ? Icons.edit
                        : Icons.visibility,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
