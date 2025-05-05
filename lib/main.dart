import 'package:flutter/material.dart';

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
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

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
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          width: MediaQuery.of(context).size.width * 0.8,
          child: FlowchartGraph(
            nodes: exampleNodes,
            displayType: FlowDisplayType.flow,
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
