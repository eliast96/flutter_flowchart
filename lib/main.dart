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
                  required bool isFromPredefinedTasks,
                }) async {
                  debugPrint("onAddDependsOnDependency");
                  var editedNode = _exampleNodes.singleWhere((e) => e.id == id);
                  if (isFromPredefinedTasks) {
                    // If the dependsOn nodes are from predefined tasks, we need to insert them first
                    var mapping = await _insertPredefinedTasksToGraph(
                      dependsOnNodes.map((e) => e.id).toList(),
                    );
                    dependsOnNodes = dependsOnNodes.map((e) {
                      return FlowchartNode(
                        id: mapping[e.id]!,
                        label: e.label,
                        status: e.status,
                        type: e.type,
                        daysToFinish: e.daysToFinish,
                        description: e.description,
                      );
                    }).toList();
                  }
                  setState(() {
                    editedNode.dependsOnNodes.addAll(dependsOnNodes);
                  });
                },
                onAddFollowUpDependency: ({
                  required String id,
                  required List<FlowchartNode> followUpNodes,
                  required bool isFromPredefinedTasks,
                }) async {
                  debugPrint("onAddFollowUpDependency");
                  var editedNode = _exampleNodes.singleWhere((e) => e.id == id);
                  if (isFromPredefinedTasks) {
                    // If the followup nodes are from predefined tasks, we need to insert them first
                    var mapping = await _insertPredefinedTasksToGraph(
                      followUpNodes.map((e) => e.id).toList(),
                    );
                    followUpNodes = followUpNodes.map((e) {
                      return FlowchartNode(
                        id: mapping[e.id]!,
                        label: e.label,
                        status: e.status,
                        type: e.type,
                        daysToFinish: e.daysToFinish,
                        description: e.description,
                      );
                    }).toList();
                  }
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
