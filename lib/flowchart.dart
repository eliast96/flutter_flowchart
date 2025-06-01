import 'package:flutter/material.dart';
import 'package:graphite/graphite.dart';
import 'dart:math';

// import 'package:klientic/providers/sql_endpoints.dart';

// List<NodeInput> flowChart = [
//   NodeInput(id: "start", next: [EdgeInput(outcome: "process")]),
//   NodeInput(id: "documents", next: [EdgeInput(outcome: "process")]),
//   NodeInput(id: "process", next: [EdgeInput(outcome: "decision")]),
//   NodeInput(
//       id: "decision",
//       size: const NodeSize(width: 100, height: 100),
//       next: [
//         EdgeInput(outcome: "processA"),
//         EdgeInput(outcome: "processB"),
//       ]),
//   NodeInput(id: "processA", next: [EdgeInput(outcome: "end")]),
//   NodeInput(id: "processB", next: [EdgeInput(outcome: "end")]),
//   NodeInput(id: "end", next: []),
// ];

enum FlowStepType { start, documents, decision, process, end }

class FlowStep {
  final String text;
  final FlowStepType type;
  bool isCompleted;
  bool isSkipped;
  bool canProgress;

  FlowStep({
    required this.text,
    required this.type,
    required this.isCompleted,
    required this.isSkipped,
    required this.canProgress,
  });
}

// Map<String, FlowStep> data = {
//   "start": FlowStep(text: "Start", type: FlowStepType.start),
//   "documents": FlowStep(text: "Documents", type: FlowStepType.documents),
//   "process": FlowStep(text: "Process", type: FlowStepType.process),
//   "decision": FlowStep(text: "Decision", type: FlowStepType.decision),
//   "processA": FlowStep(text: "Process A", type: FlowStepType.process),
//   "processB": FlowStep(text: "Process B", type: FlowStepType.process),
//   "end": FlowStep(text: "End", type: FlowStepType.end),
// };

class Flowchart extends StatefulWidget {
  final Map<String, FlowStep> data;
  final List<NodeInput> flowChart;
  final Function onDeleteProcess;
  final Function onAddOrEditProcess;
  final Function onAddFromPredefined;
  final Function onEditLinks;
  final Function onDeleteDecision;
  final Function? onCompleteTask;
  final bool isSelection;
  final Function? onSelected;
  final List<String>? disabledNodes;
  final bool? displayOnly;

  const Flowchart({
    Key? key,
    required this.data,
    required this.flowChart,
    required this.onAddOrEditProcess,
    required this.onAddFromPredefined,
    required this.onEditLinks,
    required this.onDeleteProcess,
    required this.onDeleteDecision,
    this.onCompleteTask,
    this.isSelection = false,
    this.displayOnly = false,
    this.onSelected,
    this.disabledNodes,
  }) : super(key: key);
  @override
  FlowchartState createState() => FlowchartState();
}

class FlowchartState extends State<Flowchart> {
  final viewTransformationController = TransformationController();

  @override
  void initState() {
    final zoomFactor = 0.8;
    final xTranslate = 300.0;
    final yTranslate = 300.0;
    viewTransformationController.value.setEntry(0, 0, zoomFactor);
    viewTransformationController.value.setEntry(1, 1, zoomFactor);
    viewTransformationController.value.setEntry(2, 2, zoomFactor);
    super.initState();
  }

  _buildNode(
    NodeInput node, {
    required Function onDeleteProcess,
    required Function onEditProcess,
    required Function onEditLinks,
    required Function onDeleteDecision,
    Function? onCompleteTask,
  }) {
    final info = widget.data[node.id]!;
    switch (info.type) {
      case FlowStepType.start:
        return Start(data: info);
      case FlowStepType.documents:
        return Process(
          id: node.id,
          data: info,
          onDelete: onDeleteProcess,
          onEdit: onEditProcess,
          onEditLinks: onEditLinks,
          isSelection: widget.isSelection,
          disabledNodes: widget.disabledNodes,
          onCompleted: onCompleteTask,
          displayOnly: widget.displayOnly ?? false,
        );
      // return Document(data: info);
      case FlowStepType.decision:
        return Decision(
          data: info,
          onDelete: onDeleteDecision,
          id: node.id,
        );
      case FlowStepType.process:
        return Process(
          id: node.id,
          data: info,
          onDelete: onDeleteProcess,
          onEdit: onEditProcess,
          onEditLinks: onEditLinks,
          isSelection: widget.isSelection,
          onSelected: widget.onSelected,
          disabledNodes: widget.disabledNodes,
          onCompleted: onCompleteTask,
          displayOnly: widget.displayOnly ?? false,
        );
      case FlowStepType.end:
        return End(data: info);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.flowChart;
    final screenSize = MediaQuery.of(context).size;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          InteractiveViewer(
            transformationController: viewTransformationController,
            minScale: 0.25,
            maxScale: 1,
            constrained: false,
            child: ConstrainedBox(
              // constraints: BoxConstraints(minWidth: screenSize.width),
              constraints: BoxConstraints(minWidth: screenSize.width),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: DirectGraph(
                  list: list,
                  defaultCellSize: const Size(250.0, 100.0),
                  cellPadding:
                      const EdgeInsets.symmetric(vertical: 30, horizontal: 10),
                  contactEdgesDistance: 5,
                  orientation: MatrixOrientation.Vertical,
                  nodeBuilder: (BuildContext context, NodeInput node) =>
                      Padding(
                    padding: const EdgeInsets.all(5),
                    child: _buildNode(
                      node,
                      onDeleteProcess: widget.onDeleteProcess,
                      onEditProcess: widget.onAddOrEditProcess,
                      onEditLinks: widget.onEditLinks,
                      onDeleteDecision: widget.onDeleteDecision,
                      onCompleteTask: widget.onCompleteTask,
                    ),
                  ),
                  centered: true,
                  minScale: .1,
                  maxScale: 1,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: ElevatedButton.icon(
              onPressed: () {
                if (widget.displayOnly ?? false) {
                  widget.onAddFromPredefined.call();
                } else {
                  widget.onAddOrEditProcess.call(null);
                }
              },
              label: Text("הוספת משימה"),
              icon: Icon(Icons.add_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class Start extends StatelessWidget {
  final FlowStep data;

  const Start({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(width: 3, color: Colors.green),
        borderRadius: const BorderRadius.all(Radius.circular(50)),
        color: Colors.greenAccent,
      ),
      child: Center(
        child: Text(
          data.text,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
    );
  }
}

// class Document extends StatelessWidget {
//   final FlowStep data;

//   const Document({super.key, required this.data});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       height: double.infinity,
//       decoration: BoxDecoration(
//         border: Border.all(width: 3),
//         borderRadius: const BorderRadius.all(Radius.circular(20)),
//         color: Colors.grey,
//       ),
//       child: Center(
//         child: Text(
//           data.text,
//           style: Theme.of(context).textTheme.subtitle2,
//         ),
//       ),
//     );
//   }
// }

class Process extends StatefulWidget {
  final String id;
  final FlowStep data;
  final Function onDelete;
  final Function onEdit;
  final Function onEditLinks;
  final Function? onCompleted;
  final bool isSelection;
  final bool displayOnly;
  final Function? onSelected;
  final List<String>? disabledNodes;

  Process({
    super.key,
    required this.id,
    required this.data,
    required this.onDelete,
    required this.onEdit,
    required this.onEditLinks,
    this.isSelection = false,
    this.displayOnly = false,
    this.onSelected,
    this.onCompleted,
    this.disabledNodes,
  });

  @override
  State<Process> createState() => _ProcessState();
}

class _ProcessState extends State<Process> {
  bool _isHoveringDelete = false;
  bool _isHoveringDone = false;
  bool _isHoveringEdit = false;
  bool _isHoveringEditLinks = false;
  bool _isHoveringProcess = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      child: widget.isSelection
          ? InkWell(
              onTap: () {
                if (widget.isSelection &&
                    !(widget.disabledNodes?.contains(widget.id) ?? false)) {
                  widget.onSelected!.call(widget.id);
                }
              },
              child: _getProcessContainer(context),
            )
          : _getProcessContainer(context),
      onEnter: (_) {
        if (widget.isSelection &&
            !(widget.disabledNodes?.contains(widget.id) ?? false)) {
          setState(() {
            _isHoveringProcess = true;
          });
        }
      },
      onExit: (_) {
        if (widget.isSelection &&
            !(widget.disabledNodes?.contains(widget.id) ?? false)) {
          setState(() {
            _isHoveringProcess = false;
          });
        }
      },
    );
  }

  Container _getProcessContainer(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(
          width: 3,
          color: (widget.disabledNodes?.contains(widget.id) ?? false)
              ? const Color.fromARGB(255, 86, 86, 86)
              : _isHoveringProcess
                  ? Colors.green
                  : widget.data.isCompleted
                      ? Colors.green
                      : widget.data.isSkipped
                          ? const Color.fromARGB(255, 122, 122, 122)
                          : Colors.orange,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        color: (widget.disabledNodes?.contains(widget.id) ?? false)
            ? const Color.fromARGB(255, 204, 204, 204)
            : _isHoveringProcess
                ? const Color.fromARGB(255, 170, 227, 172)
                : widget.data.isCompleted
                    ? const Color.fromARGB(255, 170, 227, 172)
                    : widget.data.isSkipped
                        ? const Color.fromARGB(255, 176, 176, 176)
                        : const Color.fromARGB(255, 253, 209, 152),
      ),
      child: Stack(
        children: [
          if (!widget.isSelection &&
              !widget.data.isCompleted &&
              !widget.data.isSkipped)
            Positioned(
              top: 7,
              left: 10,
              child: Row(
                children: [
                  InkWell(
                    child: MouseRegion(
                      child: Icon(
                        Icons.delete_rounded,
                        size: 18,
                        color: _isHoveringDelete
                            ? Colors.red
                            : const Color.fromARGB(189, 244, 67, 54),
                      ),
                      onEnter: (_) => setState(() {
                        _isHoveringDelete = true;
                      }),
                      onExit: (_) => setState(() {
                        _isHoveringDelete = false;
                      }),
                    ),
                    onTap: () async {
                      bool? res = await showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('מחיקה'),
                            content: const Text(
                                'האם אתה בטוח שברצונך למחוק משימה זו מהתהליך?',
                                style: TextStyle(fontSize: 15)),
                            actions: <Widget>[
                              TextButton(
                                child: const Text('ביטול'),
                                onPressed: () {
                                  Navigator.of(context).pop(false);
                                },
                              ),
                              TextButton(
                                child: const Text(
                                  'מחיקה',
                                  style: TextStyle(
                                      color: Colors.red, fontSize: 15),
                                ),
                                onPressed: () {
                                  Navigator.of(context).pop(true);
                                },
                              ),
                            ],
                          );
                        },
                      );
                      if (res != null && res == true) {
                        await widget.onDelete.call(widget.id);
                      }
                    },
                  ),
                  const SizedBox(width: 5),
                  InkWell(
                    child: MouseRegion(
                      child: Icon(
                        Icons.edit_rounded,
                        size: 18,
                        color: _isHoveringEdit
                            ? const Color.fromARGB(255, 255, 153, 0)
                            : const Color.fromARGB(255, 224, 134, 1),
                      ),
                      onEnter: (_) => setState(() {
                        _isHoveringEdit = true;
                      }),
                      onExit: (_) => setState(() {
                        _isHoveringEdit = false;
                      }),
                    ),
                    onTap: () async {
                      await widget.onEdit.call(widget.id);
                    },
                  ),
                  const SizedBox(width: 5),
                  InkWell(
                    child: MouseRegion(
                      child: Icon(
                        Icons.compare_arrows_rounded,
                        size: 24,
                        color: _isHoveringEditLinks
                            ? const Color.fromARGB(255, 55, 112, 233)
                            : const Color.fromARGB(255, 22, 149, 241),
                      ),
                      onEnter: (_) => setState(() {
                        _isHoveringEditLinks = true;
                      }),
                      onExit: (_) => setState(() {
                        _isHoveringEditLinks = false;
                      }),
                    ),
                    onTap: () async {
                      await widget.onEditLinks.call(widget.id);
                    },
                  ),
                ],
              ),
            ),
          if (!widget.displayOnly &&
              widget.onCompleted != null &&
              !widget.data.isCompleted &&
              !widget.data.isSkipped &&
              widget.data.canProgress)
            Positioned(
              top: 7,
              right: 10,
              child: Row(
                children: [
                  InkWell(
                    child: MouseRegion(
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: _isHoveringDone
                            ? Colors.green
                            : const Color.fromARGB(182, 76, 175, 79),
                      ),
                      onEnter: (_) => setState(() {
                        _isHoveringDone = true;
                      }),
                      onExit: (_) => setState(() {
                        _isHoveringDone = false;
                      }),
                    ),
                    onTap: () async {
                      bool? res = await showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('השלמת משימה'),
                            content: const Text(
                                'האם אתה בטוח שברצונך לסמן משימה זו כ-״בוצעה״?',
                                style: TextStyle(fontSize: 15)),
                            actions: <Widget>[
                              TextButton(
                                child: const Text('ביטול'),
                                onPressed: () {
                                  Navigator.of(context).pop(false);
                                },
                              ),
                              TextButton(
                                child: const Text('אישור'),
                                onPressed: () {
                                  Navigator.of(context).pop(true);
                                },
                              ),
                            ],
                          );
                        },
                      );
                      if (res != null && res == true) {
                        await widget.onCompleted!.call(widget.id);
                      }
                    },
                  ),
                ],
              ),
            ),
          Center(
            child: Text(
              widget.data.text,
              textDirection: TextDirection.rtl,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}

class Decision extends StatefulWidget {
  final FlowStep data;
  final Function onDelete;
  final String id;

  const Decision({
    super.key,
    required this.id,
    required this.data,
    required this.onDelete,
  });

  @override
  State<Decision> createState() => _DecisionState();
}

class _DecisionState extends State<Decision> {
  bool _isHoveringDelete = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Transform.rotate(
          angle: pi / 4,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                width: 3,
                color: Colors.deepOrangeAccent,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(5)),
              color: Colors.orangeAccent,
            ),
          ),
        ),
        SizedBox(
          child: Center(
            child: Text(
              widget.data.text,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        Positioned(
          left: -10,
          child: InkWell(
            child: MouseRegion(
              child: Icon(
                Icons.delete_rounded,
                size: 18,
                color: _isHoveringDelete
                    ? Colors.red
                    : const Color.fromARGB(189, 244, 67, 54),
              ),
              onEnter: (_) => setState(() {
                _isHoveringDelete = true;
              }),
              onExit: (_) => setState(() {
                _isHoveringDelete = false;
              }),
            ),
            onTap: () async {
              bool? res = await showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('מחיקה'),
                    content: const Text(
                        'האם אתה בטוח שברצונך לבטל את התלות בהחלטות?',
                        style: TextStyle(fontSize: 15)),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('ביטול'),
                        onPressed: () {
                          Navigator.of(context).pop(false);
                        },
                      ),
                      TextButton(
                        child: const Text(
                          'מחיקה',
                          style: TextStyle(color: Colors.red, fontSize: 15),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(true);
                        },
                      ),
                    ],
                  );
                },
              );
              if (res != null && res == true) {
                await widget.onDelete.call(
                  widget.id.replaceAll("__FOLLOWUP", ""),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}

class End extends StatelessWidget {
  final FlowStep data;

  const End({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(width: 3, color: Colors.red),
        borderRadius: const BorderRadius.all(Radius.circular(50)),
        color: Colors.redAccent,
      ),
      child: Center(
        child: Text(
          data.text,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
    );
  }
}
